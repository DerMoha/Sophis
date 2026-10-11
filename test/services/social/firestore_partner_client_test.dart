import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/firestore_partner_client.dart';
import 'package:sophis/services/social/social_callable_client.dart';
import 'package:sophis/services/social/social_local_store.dart';

final class _Credentials implements SocialCredentials, SocialCredentialSession {
  @override
  String? accountId = 'alice';
  @override
  int authenticationVersion = 0;
  Future<SocialTokens> Function(String)? resolve;
  @override
  Future<SocialTokens> tokensFor(String uid) async => resolve == null
      ? SocialTokens(accountId: uid, idToken: 'alice-token')
      : await resolve!(uid);
}

void main() {
  late SocialLocalStore store;
  late _Credentials credentials;
  late SocialSession session;
  late FirestorePartnerClient client;
  late int requests;
  late Future<http.Response> Function(http.Request) respond;
  setUp(() async {
    store = SocialLocalStore(NativeDatabase.memory());
    session = await store.switchAccount('alice');
    credentials = _Credentials();
    requests = 0;
    respond = (r) async => http.Response(
          jsonEncode({
            'fields': {
              'accountId': {'stringValue': 'alice'},
              'displayName': {'stringValue': 'Alice'},
            },
            'updateTime': '2026-10-08T12:00:00Z',
          }),
          200,
        );
    client = FirestorePartnerClient(
      credentials: credentials,
      store: store,
      httpClient: MockClient((r) async {
        requests++;
        return respond(r);
      }),
      projectId: 'sophis-test',
    );
  });
  tearDown(() async {
    await store.close();
  });
  test('sent captured auth to Firestore over HTTPS with no redirects',
      () async {
    respond = (r) async {
      expect(r.url.host, 'firestore.googleapis.com');
      expect(r.url.scheme, 'https');
      expect(r.url.path, endsWith('/partnerProfiles/alice'));
      expect(r.headers['Authorization'], 'Bearer alice-token');
      expect(r.followRedirects, isFalse);
      return http.Response(
        '{"fields":{},"updateTime":"2026-10-08T12:00:00Z"}',
        200,
      );
    };
    expect((await client.call(session, 'ownProfile', {})).isSuccess, isTrue);
  });
  test('stopped account replacement during token refresh before transmitting',
      () async {
    final token = Completer<SocialTokens>();
    credentials.resolve = (_) => token.future;
    final pending = client.call(session, 'ownProfile', {});
    await Future<void>.delayed(Duration.zero);
    credentials.accountId = 'bob';
    await store.switchAccount('bob');
    token
        .complete(const SocialTokens(accountId: 'alice', idToken: 'old-token'));
    expect((await pending as Failure).errorType, ServiceErrorType.authFailed);
    expect(requests, 0);
  });
  test('rejected same-UID reauthentication during token refresh', () async {
    credentials.resolve = (uid) async {
      credentials.authenticationVersion++;
      return SocialTokens(accountId: uid, idToken: 'new-token');
    };
    expect(
      (await client.call(session, 'ownProfile', {}) as Failure).errorType,
      ServiceErrorType.authFailed,
    );
    expect(requests, 0);
  });
  test('discarded a response arriving after an account switch', () async {
    respond = (r) async {
      credentials.accountId = 'bob';
      await store.switchAccount('bob');
      return http.Response('{"fields":{},"updateTime":"version"}', 200);
    };
    expect(
      (await client.call(session, 'ownProfile', {}) as Failure).errorType,
      ServiceErrorType.authFailed,
    );
  });
  test('rejected substituted credential identity and stale sessions', () async {
    credentials.resolve =
        (_) async => const SocialTokens(accountId: 'bob', idToken: 'bob-token');
    expect((await client.call(session, 'ownProfile', {})).isFailure, isTrue);
    expect(requests, 0);
    await store.switchAccount('alice');
    expect((await client.call(session, 'ownProfile', {})).isFailure, isTrue);
    expect(requests, 0);
  });
  test('kept quota and transport failures retryable', () async {
    for (final status in ['RESOURCE_EXHAUSTED', 'UNAVAILABLE']) {
      respond = (_) async => http.Response(
            jsonEncode({
              'error': {'status': status},
            }),
            429,
          );
      final result = await client.call(session, 'ownProfile', {}) as Failure;
      expect(
        result.errorType,
        status == 'RESOURCE_EXHAUSTED'
            ? ServiceErrorType.rateLimited
            : ServiceErrorType.network,
      );
    }
    credentials.resolve = (_) async =>
        throw const SocialCredentialFailure(ServiceErrorType.network);
    expect(
      (await client.call(session, 'ownProfile', {}) as Failure).errorType,
      ServiceErrorType.network,
    );
  });
  test('treated non-JSON gateway errors as transient failures', () async {
    respond =
        (_) async => http.Response('<html>Service unavailable</html>', 503);
    expect(
      (await client.call(session, 'ownProfile', {}) as Failure).errorType,
      ServiceErrorType.network,
    );
  });
  test(
      'bounded concurrent-write retries and rejected unsupported publishing actions',
      () async {
    respond = (_) async => http.Response('{"error":{"status":"ABORTED"}}', 409);
    expect(
      (await client.call(session, 'ownProfile', {}) as Failure).errorType,
      ServiceErrorType.network,
    );
    expect(requests, 3);
    requests = 0;
    expect((await client.call(session, 'publish', {})).isFailure, isTrue);
    expect(requests, 0);
  });
  test('rejected payload identity injection and malformed responses', () async {
    expect(
      (await client.call(session, 'ownProfile', {'authorId': 'bob'})).isFailure,
      isTrue,
    );
    expect(requests, 0);
    respond = (_) async => http.Response('not-json', 200);
    expect(
      (await client.call(session, 'ownProfile', {}) as Failure).errorType,
      ServiceErrorType.parseError,
    );
  });
  test(
      'summed exactly 200 contributions and refused an incomplete larger total',
      () async {
    for (final overLimit in [false, true]) {
      var pages = 0;
      respond = (request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'updateTime': 'version',
              'fields': {
                'status': {'stringValue': 'accepted'},
                'revokedAt': {'nullValue': null},
                'participants': {
                  'arrayValue': {
                    'values': [
                      {'stringValue': 'alice'},
                      {'stringValue': 'bob'},
                    ],
                  },
                },
                'settings': {
                  'mapValue': {
                    'fields': {
                      'bob': {
                        'mapValue': {
                          'fields': {
                            'summaries': {'booleanValue': true},
                            'summaryGeneration': {'integerValue': '0'},
                          },
                        },
                      },
                    },
                  },
                },
              },
            }),
            200,
          );
        }
        final page = pages++;
        return http.Response(
          jsonEncode(
            page == 10 && !overLimit
                ? <Object>[]
                : [
                    for (var i = 0; i < 20; i++)
                      {
                        'document': {
                          'name':
                              'projects/sophis-test/databases/(default)/documents/partnerConnections/connection/members/bob/contributions/item_${page}_$i',
                          'updateTime': 'version',
                          'fields': {
                            'calories': {'doubleValue': 10.0},
                            'protein': {'doubleValue': 1.0},
                            'carbs': {'doubleValue': 1.0},
                            'fat': {'doubleValue': 1.0},
                          },
                        },
                      },
                  ],
          ),
          200,
        );
      };
      final result = await client.call(session, 'partnerSummaries', {
        'connectionId': 'connection',
        'localDate': '2026-10-08',
        'timeZone': 'Europe/Berlin',
      });
      expect(pages, 11);
      if (overLimit) {
        expect((result as Failure).errorType, ServiceErrorType.rateLimited);
      } else {
        final summary =
            ((result.value as Map)['summaries'] as List).single as Map;
        expect(summary['calories'], 2000.0);
      }
    }
  });
  test(
      'calibrated device clocks and preserved published origins during history replay',
      () async {
    var now = DateTime.utc(2026, 10, 8, 12);
    final serverNow = now.add(const Duration(seconds: 5));
    var readTime = serverNow;
    client = FirestorePartnerClient(
      credentials: credentials,
      store: store,
      httpClient: MockClient((request) => respond(request)),
      projectId: 'sophis-test',
      clock: () => now,
    );
    Map<String, dynamic> encode(Object? value) => switch (value) {
          DateTime() => {'timestampValue': value.toIso8601String()},
          bool() => {'booleanValue': value},
          int() => {'integerValue': value.toString()},
          String() => {'stringValue': value},
          List() => {
              'arrayValue': {'values': value.map(encode).toList()},
            },
          Map() => {
              'mapValue': {
                'fields': value.map((key, v) => MapEntry(key, encode(v))),
              },
            },
          _ => {'nullValue': null},
        };
    final settings = <String, dynamic>{
      'meals': true,
      'paused': false,
      'revision': 1,
      'mealGeneration': 0,
      'mealStart': serverNow,
      'mealTimeZone': 'Europe/Berlin',
    };
    final writes = <Map<String, dynamic>>[];
    Map<String, dynamic>? existing;
    respond = (request) async {
      if (request.url.path.endsWith(':runQuery')) {
        return http.Response(
          jsonEncode([
            {'readTime': readTime.toIso8601String()},
          ]),
          200,
        );
      }
      if (request.url.path.endsWith('/partnerConnections/connection')) {
        return http.Response(
          jsonEncode({
            'updateTime': 'version',
            'fields': {
              'status': encode('accepted'),
              'revokedAt': encode(null),
              'participants': encode(['alice', 'bob']),
              'settings': encode({'alice': settings, 'bob': {}}),
            },
          }),
          200,
        );
      }
      if (request.method == 'GET') {
        return existing == null
            ? http.Response('{"error":{"status":"NOT_FOUND"}}', 404)
            : http.Response(
                jsonEncode({'updateTime': 'version', 'fields': existing}),
                200,
              );
      }
      final write = ((jsonDecode(request.body) as Map)['writes'] as List).single
          as Map<String, dynamic>;
      writes.add(write);
      existing =
          Map<String, dynamic>.from((write['update'] as Map)['fields'] as Map)
            ..['publishedAt'] = encode(serverNow);
      return http.Response('{}', 200);
    };
    // A fresh server read calibrates the five-second skew. Stale document
    // updateTime values must never be treated as the current server clock.
    expect((await client.call(session, 'partners', {})).isSuccess, isTrue);
    now = now.add(const Duration(milliseconds: 100));
    final payload = <String, dynamic>{
      'connectionId': 'connection',
      'sourceMealId': 'rice',
      'sourceRevision': 1,
      'consentRevision': 1,
      'originallyLoggedAt': now.millisecondsSinceEpoch,
      'changedAt': now.millisecondsSinceEpoch,
      'localDate': '2026-10-08',
      'timeZone': 'Europe/Berlin',
      'mealCategory': 'dinner',
      'snapshot': {
        'schemaVersion': 1,
        'title': 'Rice',
        'servings': 1,
        'items': [
          {
            'name': 'Rice',
            'calories': 200,
            'protein': 4,
            'carbs': 44,
            'fat': 1,
            'fiber': 2,
          }
        ],
      },
    };
    expect(
      (await client.call(session, 'syncPartnerMeal', payload)).isSuccess,
      isTrue,
    );
    expect(writes, hasLength(1));
    final firstOrigin = existing!['originallyLoggedAt'];
    expect(
      DateTime.parse((firstOrigin as Map)['timestampValue'] as String),
      serverNow.add(const Duration(milliseconds: 100)),
    );
    now = now.add(const Duration(seconds: 2));
    readTime = serverNow.add(const Duration(seconds: 3));
    expect((await client.call(session, 'partners', {})).isSuccess, isTrue);
    expect(
      (await client.call(session, 'syncPartnerMeal', {
        ...payload,
        'sourceRevision': 2,
        'changedAt': now.millisecondsSinceEpoch,
      }))
          .isSuccess,
      isTrue,
    );
    expect(writes, hasLength(2));
    expect(existing!['originallyLoggedAt'], firstOrigin);
    // Upgrading an old permission generation must preserve the server origin
    // even when a later read recalibrates the device clock differently.
    settings['mealGeneration'] = 1;
    readTime = serverNow.add(const Duration(seconds: 10));
    expect((await client.call(session, 'partners', {})).isSuccess, isTrue);
    expect(
        (await client.call(session, 'syncPartnerMeal', {
          ...payload,
          'sourceRevision': 2,
          'changedAt': now.millisecondsSinceEpoch,
        }))
            .isSuccess,
        isTrue,);
    expect(writes, hasLength(3));
    expect(existing!['originallyLoggedAt'], firstOrigin);
    existing = null;
    expect(
      (await client.call(session, 'syncPartnerMeal', {
        ...payload,
        'sourceMealId': 'historical',
        'originallyLoggedAt':
            now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
      }))
          .isSuccess,
      isTrue,
    );
    expect(writes, hasLength(4));
  });
  test('refused production projects over the emulator transport', () {
    expect(
      () => FirestorePartnerClient(
        credentials: credentials,
        store: store,
        httpClient: http.Client(),
        projectId: 'real-project',
        emulatorHost: '127.0.0.1',
      ),
      throwsArgumentError,
    );
  });
}
