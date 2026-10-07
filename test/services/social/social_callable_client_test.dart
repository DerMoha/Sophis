import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/social_callable_client.dart';
import 'package:sophis/services/social/social_local_store.dart';
import 'package:sophis/services/social/social_queue_runner.dart';

class _Credentials implements SocialCredentials {
  @override
  String? accountId = 'alice';
  Future<SocialTokens> Function(String)? resolve;
  @override
  Future<SocialTokens> tokensFor(String accountId) async => resolve == null
      ? SocialTokens(
          accountId: accountId,
          idToken: 'captured-token',
          appCheckToken: 'app-token',
        )
      : await resolve!(accountId);
}

void main() {
  late SocialLocalStore store;
  late _Credentials credentials;
  late SocialSession session;
  late SocialCallableClient client;
  late int requests;
  Future<http.Response> Function(http.Request)? respond;
  setUp(() async {
    store = SocialLocalStore(NativeDatabase.memory());
    credentials = _Credentials();
    session = await store.switchAccount('alice');
    requests = 0;
    respond = null;
    client = SocialCallableClient(
      credentials: credentials,
      store: store,
      endpoint: Uri.https('example.test', '/social'),
      client: MockClient((request) async {
        requests++;
        if (respond != null) return respond!(request);
        expect(request.headers['Authorization'], 'Bearer captured-token');
        expect(request.headers['X-Firebase-AppCheck'], 'app-token');
        expect(request.followRedirects, isFalse);
        expect(jsonDecode(request.body), {
          'data': {'action': 'feed'},
        });
        return http.Response('{"result":{"posts":[]}}', 200);
      }),
    );
  });
  tearDown(() async => store.close());

  group('SocialCallableClient', () {
    test('sent captured credentials and the callable envelope', () async {
      expect((await client.call(session, 'feed', {})).isSuccess, isTrue);
      expect(requests, 1);
    });
    test('kept transient credential-refresh failures retryable', () async {
      credentials.resolve = (_) async =>
          throw const SocialCredentialFailure(ServiceErrorType.network);
      expect(
        (await client.call(session, 'feed', {}) as Failure).errorType,
        ServiceErrorType.network,
      );
      expect(requests, 0);
    });
    test('stopped an account switch during token refresh before sending',
        () async {
      final refresh = Completer<SocialTokens>();
      credentials.resolve = (_) => refresh.future;
      final pending = client.call(session, 'feed', {});
      await Future<void>.delayed(Duration.zero);
      credentials.accountId = 'bob';
      await store.switchAccount('bob');
      refresh.complete(
        const SocialTokens(
          accountId: 'alice',
          idToken: 'old-token',
          appCheckToken: 'app',
        ),
      );
      final result = await pending;
      expect((result as Failure).errorType, ServiceErrorType.authFailed);
      expect(requests, 0);
    });
    test('rejected a token provider substituting another identity', () async {
      credentials.resolve = (_) async => const SocialTokens(
            accountId: 'bob',
            idToken: 'bob-token',
            appCheckToken: 'app',
          );
      expect((await client.call(session, 'feed', {})).isFailure, isTrue);
      expect(requests, 0);
    });
    test('rejected the previous generation after logout and same-account login',
        () async {
      await store.switchAccount(null);
      await store.switchAccount('alice');
      expect((await client.call(session, 'feed', {})).isFailure, isTrue);
      expect(requests, 0);
    });
    test('discarded a response after an in-flight account switch', () async {
      respond = (_) async {
        credentials.accountId = 'bob';
        await store.switchAccount('bob');
        return http.Response('{"result":{"private":"alice"}}', 200);
      };
      expect((await client.call(session, 'feed', {})).isFailure, isTrue);
      expect(requests, 1);
    });
    test('required device verification before production requests', () async {
      credentials.resolve = (_) async =>
          const SocialTokens(accountId: 'alice', idToken: 'alice-token');
      expect((await client.call(session, 'feed', {})).isFailure, isTrue);
      expect(requests, 0);
    });
    test('treated callable errors as failures even with HTTP success',
        () async {
      respond = (_) async => http.Response(
            '{"result":{},"error":{"status":"PERMISSION_DENIED","message":"private backend details"}}',
            200,
          );
      final result = await client.call(session, 'feed', {});
      expect((result as Failure).errorType, ServiceErrorType.authFailed);
      expect(result.message, isNot(contains('backend details')));
    });
    test('kept rate-limited queued work retryable', () async {
      final command = SocialQueuedCommand(
        operationId: 'one',
        action: 'deletePost',
        targetId: 'post',
        payload: {'postId': 'post'},
        createdAt: DateTime.utc(2026),
      );
      await store.enqueue(session, command);
      respond = (_) async =>
          http.Response('{"error":{"status":"RESOURCE_EXHAUSTED"}}', 429);
      await SocialQueueRunner(store: store, transport: client)
          .flush(now: DateTime.utc(2026));
      expect(await store.nextCommand(session, DateTime.utc(2026)), isNull);
      expect(
        await store.nextCommand(
          session,
          DateTime.utc(2026).add(const Duration(seconds: 3)),
        ),
        isNotNull,
      );
    });
    test('rejected oversized and malformed server responses', () async {
      respond = (_) async => http.Response('x' * (2 * 1024 * 1024 + 1), 200);
      expect(
        (await client.call(session, 'feed', {}) as Failure).errorType,
        ServiceErrorType.parseError,
      );
      respond = (_) async => http.Response('{}', 200);
      expect((await client.call(session, 'feed', {})).isFailure, isTrue);
    });
    test('rejected identity overrides without sending', () async {
      expect(
        (await client.call(session, 'feed', {'authorId': 'bob'})).isFailure,
        isTrue,
      );
      expect(requests, 0);
    });
  });
}
