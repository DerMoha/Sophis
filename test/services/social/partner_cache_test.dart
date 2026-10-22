import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/social_callable_client.dart';
import 'package:sophis/services/social/social_local_store.dart';
import 'package:sophis/services/social/social_partner_repository.dart';

class _Client implements SocialClient {
  final SocialLocalStore store;
  _Client(this.store);
  @override
  String? accountId = 'alice';
  late Future<ServiceResult<Object?>> Function(String) respond;
  @override
  Future<SocialSession?> captureSession() => store.session();
  @override
  Future<ServiceResult<Object?>> call(
    SocialSession session,
    String action,
    Map<String, dynamic> payload,
  ) =>
      respond(action);
  @override
  Future<ServiceResult<void>> send(
    SocialSession session,
    SocialQueuedCommand command,
  ) async =>
      const Success(null);
}

Map<String, dynamic> connections({int revision = 1}) => {
      'connections': [
        {
          'id': 'one',
          'displayName': 'Bob',
          'participants': ['alice', 'bob'],
          'inviterId': 'alice',
          'status': 'accepted',
          'settings': {
            'alice': {'revision': 1},
            'bob': {'revision': revision},
          },
        }
      ],
    };

void main() {
  late SocialLocalStore store;
  late SocialSession session;
  var storeClosed = false;
  late _Client client;
  late SocialPartnerRepository repository;
  const payload = {
    'connectionId': 'one',
    'localDate': '2026-10-14',
    'timeZone': 'Europe/Berlin',
  };
  const meals = {
    'meals': [
      {'authorId': 'bob', 'id': 'rice'},
    ],
    'cursor': null,
  };
  setUp(() async {
    storeClosed = false;
    store = SocialLocalStore(NativeDatabase.memory());
    session = await store.switchAccount('alice');
    client = _Client(store)
      ..respond = (action) async =>
          Success<Object?>(action == 'partners' ? connections() : meals);
    repository = SocialPartnerRepository(client, store: store);
    await repository.connections();
  });
  tearDown(() async {
    if (!storeClosed) await store.close();
  });

  test('cached responses by day, timezone and page with canonical keys',
      () async {
    await repository.request('partnerMeals', payload);
    final cached = await repository.cached('partnerMeals', {
      'timeZone': 'Europe/Berlin',
      'localDate': '2026-10-14',
      'connectionId': 'one',
    });
    expect(cached?.data, meals);
    expect(cached?.savedAt, isNotNull);
    expect(
      await repository
          .cached('partnerMeals', {...payload, 'localDate': '2026-10-13'}),
      isNull,
    );
    expect(
      await repository.cached('partnerMeals', {...payload, 'timeZone': 'UTC'}),
      isNull,
    );
    expect(
      await repository.cached('partnerMeals', {
        ...payload,
        'cursor': {'id': 'rice'},
      }),
      isNull,
    );
  });

  test('retained saved data offline but removed it on access denial', () async {
    await repository.request('partnerMeals', payload);
    client.respond =
        (_) async => const Failure(ServiceErrorType.network, 'Offline');
    expect(
      (await repository.request('partnerMeals', payload)).isFailure,
      isTrue,
    );
    expect(await repository.cached('partnerMeals', payload), isNotNull);
    client.respond =
        (_) async => const Failure(ServiceErrorType.authFailed, 'Denied');
    await repository.request('partnerMeals', payload);
    expect(await repository.cached('partnerMeals', payload), isNull);
    expect(await repository.cachedConnections(), isEmpty);
  });

  test('invalidated saved days when connection settings changed', () async {
    await repository.request('partnerMeals', payload);
    client.respond = (_) async => Success<Object?>(connections(revision: 2));
    await repository.connections();
    expect(await repository.cached('partnerMeals', payload), isNull);
  });

  test('kept the latest connection cache when refreshes completed out of order',
      () async {
    final started = Completer<void>();
    final old = Completer<ServiceResult<Object?>>();
    client.respond = (_) {
      started.complete();
      return old.future;
    };
    final first = repository.connections();
    await started.future;
    client.respond = (_) async => Success<Object?>(connections(revision: 2));
    await repository.connections();
    old.complete(Success<Object?>(connections()));
    await first;
    expect(
      (await repository.cachedConnections())!.single.otherSettings['revision'],
      2,
    );
  });

  test('did not restore removed data from a late response', () async {
    final started = Completer<void>();
    final response = Completer<ServiceResult<Object?>>();
    client.respond = (_) {
      started.complete();
      return response.future;
    };
    final request = repository.request('partnerMeals', payload);
    await started.future;
    await store.clearPartnerCache(session, connectionId: 'one');
    response.complete(const Success<Object?>(meals));
    expect((await request).isFailure, isTrue);
    expect(await repository.cached('partnerMeals', payload), isNull);
  });

  test('cleared cached profile and partner data across account changes',
      () async {
    await store.cachePartnerResponse(
      session,
      'ownProfile',
      {'accountId': 'alice', 'displayName': 'Alice'},
    );
    await repository.request('partnerMeals', payload);
    final bob = await store.switchAccount('bob');
    await store
        .cachePartnerResponse(session, 'ownProfile', {'accountId': 'alice'});
    expect(await store.partnerCache(bob, 'ownProfile'), isNull);
    expect(await store.partnerCache(bob, 'partners'), isNull);
    final alice = await store.switchAccount('alice');
    expect(await store.partnerCache(alice, 'partners'), isNull);
  });

  test('bounded saved detail responses without removing connections', () async {
    final state = await store.cachedConnectionState(session, 'one');
    for (var i = 0; i < 105; i++) {
      await store.cachePartnerResponse(
        session,
        'day-$i',
        meals,
        connectionId: 'one',
        connectionState: state,
      );
    }
    final count = await store
        .customSelect(
          'SELECT COUNT(*) AS n FROM social_partner_cache WHERE connection_id IS NOT NULL',
        )
        .getSingle();
    expect(count.read<int>('n'), 100);
    expect(await repository.cachedConnections(), hasLength(1));
  });

  test('preserved partner cache during legacy publishing cleanup', () async {
    await repository.request('partnerMeals', payload);
    await store.retirePublishing();
    expect(await repository.cached('partnerMeals', payload), isNotNull);
    expect(await repository.cachedConnections(), hasLength(1));
  });

  test('migrated version two and preserved cache across database reopening',
      () async {
    await store.close();
    storeClosed = true;
    final directory = await Directory.systemTemp.createTemp('partner-cache-');
    final file = File('${directory.path}/social.sqlite');
    var persisted = SocialLocalStore(
      NativeDatabase(
        file,
        setup: (db) {
          db.execute(
            'CREATE TABLE social_session (singleton INTEGER PRIMARY KEY, account_id TEXT, generation INTEGER NOT NULL)',
          );
          db.execute("INSERT INTO social_session VALUES (1, 'alice', 1)");
          db.execute('PRAGMA user_version = 2');
        },
      ),
    );
    try {
      final expected = await persisted.session();
      await persisted.cachePartnerResponse(expected, 'partners', connections());
      await persisted.close();
      persisted = SocialLocalStore(NativeDatabase(file));
      expect(
        (await persisted.partnerCache(await persisted.session(), 'partners'))
            ?.data,
        connections(),
      );
    } finally {
      await persisted.close();
      await directory.delete(recursive: true);
    }
  });
}
