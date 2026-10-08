import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/social_local_store.dart';
import 'package:sophis/services/social/social_queue_runner.dart';

final class _Transport implements SocialCommandTransport {
  @override
  String? accountId = 'alice';
  final List<String> sent = [];
  ServiceResult<void> result = const Success(null);
  Future<ServiceResult<void>> Function()? callback;

  @override
  Future<ServiceResult<void>> send(
    SocialSession session,
    SocialQueuedCommand command,
  ) async {
    if (accountId != session.accountId) {
      return const Failure(ServiceErrorType.authFailed, 'Account changed');
    }
    sent.add(command.operationId);
    if (callback == null) return result;
    return callback!();
  }
}

void main() {
  final now = DateTime(2026, 10, 7);
  SocialQueuedCommand command(
    String operation, {
    String action = 'publish',
    String target = 'post1',
  }) =>
      SocialQueuedCommand(
        operationId: operation,
        action: action,
        targetId: target,
        payload: {'operationId': operation},
        createdAt: now,
      );
  late SocialLocalStore store;
  late SocialSession alice;
  var storeClosed = false;
  setUp(() async {
    storeClosed = false;
    store = SocialLocalStore(NativeDatabase.memory());
    alice = await store.switchAccount('alice');
  });
  tearDown(() async {
    if (!storeClosed) await store.close();
  });

  group('SocialLocalStore', () {
    test('retired posting work while retaining partner updates and deletion', () async {
      await store.enqueue(alice, command('post'));
      await store.enqueue(alice, command('reaction', action: 'react', target: 'reaction'));
      await store.enqueue(alice, command('partner', action: 'syncPartnerMeal', target: 'meal'));
      await store.enqueue(alice, command('delete', action: 'deletePost', target: 'old-post'));
      await store.retirePublishing();
      final transport = _Transport();
      await SocialQueueRunner(store: store, transport: transport).flush(now: now);
      expect(transport.sent, ['delete', 'partner']);
    });
    test('deduplicated offline publication operations', () async {
      await store.enqueue(alice, command('one'));
      await store.enqueue(alice, command('one'));
      final transport = _Transport();
      await SocialQueueRunner(store: store, transport: transport)
          .flush(now: now);
      expect(transport.sent, ['one']);
      expect(await store.nextCommand(alice, now), isNull);
    });
    test('stopped automatic replay after a rate limit and retained other work', () async {
      await store.enqueue(alice, command('one'));
      await store.enqueue(alice, command('two', target: 'post2'));
      final transport = _Transport()..result = const Failure(ServiceErrorType.rateLimited, 'Limit reached');
      final healthy = await SocialQueueRunner(store: store, transport: transport).flush(now: now);
      expect(healthy, isFalse);
      expect(transport.sent, ['one']);
      expect((await store.nextCommand(alice, now))?.operationId, 'two');
    });
    test('deleted stale edits and publications before replay', () async {
      await store.enqueue(alice, command('publish'));
      await store.enqueue(alice, command('edit', action: 'editPost'));
      await store.enqueue(alice, command('delete', action: 'deletePost'));
      await store.enqueue(alice, command('stale', action: 'editPost'));
      expect((await store.nextCommand(alice, now))?.action, 'deletePost');
      await store.acknowledge(alice, 'delete');
      expect(await store.nextCommand(alice, now), isNull);
    });
    test('cleared caches and queued work transactionally on switching accounts',
        () async {
      await store.enqueue(alice, command('one'));
      await store.cacheFeed(
        alice,
        [
          {'id': 'privatePost'},
        ],
        now,
      );
      final bob = await store.switchAccount('bob');
      expect(await store.cachedFeed(bob), isEmpty);
      expect(await store.nextCommand(bob, now), isNull);
      await store.cacheFeed(
        alice,
        [
          {'id': 'staleResponse'},
        ],
        now,
      );
      expect(await store.cachedFeed(bob), isEmpty);
      await expectLater(
        store.enqueue(alice, command('stale')),
        throwsStateError,
      );
    });
    test('did not send queued work using another account identity', () async {
      await store.enqueue(alice, command('one'));
      final transport = _Transport()..accountId = 'bob';
      await SocialQueueRunner(store: store, transport: transport)
          .flush(now: now);
      expect(transport.sent, isEmpty);
      expect(await store.nextCommand(alice, now), isNotNull);
    });
    test('discarded old in-flight responses and kept the new account queue',
        () async {
      await store.enqueue(alice, command('one'));
      final response = Completer<ServiceResult<void>>();
      final started = Completer<void>();
      final transport = _Transport()
        ..callback = () {
          started.complete();
          return response.future;
        };
      final runner = SocialQueueRunner(store: store, transport: transport);
      final flushing = runner.flush(now: now);
      await started.future;
      final bob = await store.switchAccount('bob');
      await store.enqueue(bob, command('one'));
      transport.accountId = 'bob';
      response.complete(const Success(null));
      await flushing;
      expect(await store.nextCommand(bob, now), isNotNull);
    });
    test(
        'backed off network failures and stopped authorization failures for review',
        () async {
      await store.enqueue(alice, command('one'));
      final transport = _Transport()
        ..result = const Failure(ServiceErrorType.network, 'Offline');
      final runner = SocialQueueRunner(store: store, transport: transport);
      await runner.flush(now: now);
      expect(await store.nextCommand(alice, now), isNull);
      expect(
        (await store.nextCommand(alice, now.add(const Duration(seconds: 3))))
            ?.attempts,
        1,
      );
      transport.result = const Failure(ServiceErrorType.authFailed, 'Removed');
      await runner.flush(now: now.add(const Duration(seconds: 3)));
      expect(
        await store.nextCommand(alice, now.add(const Duration(days: 1))),
        isNull,
      );
    });
    test('retained durable pending work after the database reopened', () async {
      await store.close();
      storeClosed = true;
      final directory =
          await Directory.systemTemp.createTemp('sophis_social_test_');
      try {
        final file = File('${directory.path}/social.sqlite');
        final first = SocialLocalStore(NativeDatabase(file));
        final session = await first.switchAccount('alice');
        await first.enqueue(session, command('durable'));
        await first.close();
        final reopened = SocialLocalStore(NativeDatabase(file));
        expect(
          (await reopened.nextCommand(await reopened.session(), now))
              ?.operationId,
          'durable',
        );
        await reopened.close();
      } finally {
        await directory.delete(recursive: true);
      }
    });
  });
}
