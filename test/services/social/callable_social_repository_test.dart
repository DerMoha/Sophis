import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/social/social_snapshot.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/callable_social_repository.dart';
import 'package:sophis/services/social/social_callable_client.dart';
import 'package:sophis/services/social/social_local_store.dart';
import 'package:sophis/services/social/social_queue_runner.dart';
import 'package:sophis/services/social/social_repository.dart';

class _Credentials implements SocialCredentials {
  @override
  String? get accountId => 'alice';
  @override
  Future<SocialTokens> tokensFor(String uid) async =>
      SocialTokens(accountId: uid, idToken: 'token', appCheckToken: 'app');
}

void main() {
  late SocialLocalStore store;
  late CallableSocialRepository repository;
  late SocialCallableClient client;
  late List<Map<String, dynamic>> sent;
  Map<String, dynamic>? feed;
  final snapshot = SocialSnapshot.fromEntries(
    [
      FoodEntry(
        id: 'private',
        name: 'Rice',
        calories: 100,
        protein: 2,
        carbs: 20,
        fat: 1,
        timestamp: DateTime(2026),
        meal: 'lunch',
      ),
    ],
    title: 'Lunch',
  );
  setUp(() async {
    store = SocialLocalStore(NativeDatabase.memory());
    await store.switchAccount('alice');
    sent = [];
    feed = null;
    client = SocialCallableClient(
      credentials: _Credentials(),
      store: store,
      endpoint: Uri.https('example.test', '/social'),
      client: MockClient((request) async {
        final data =
            (jsonDecode(request.body) as Map)['data'] as Map<String, dynamic>;
        sent.add(data);
        return http.Response(
          jsonEncode({
            'result': data['action'] == 'feed'
                ? (feed ?? {'posts': [], 'cursor': null})
                : {},
          }),
          200,
        );
      }),
    );
    repository = CallableSocialRepository(
      client: client,
      store: store,
      signOut: () async {
        await store.switchAccount(null);
        return const Success(null);
      },
    );
  });
  tearDown(() async => store.close());
  group('CallableSocialRepository', () {
    test('queued snapshots offline and used the server deterministic post ID',
        () async {
      final result = await repository.publish(
        operationId: 'one',
        snapshot: snapshot,
        nutritionVisible: true,
        isRecipe: false,
      );
      expect(
        result.value,
        sha256.convert(utf8.encode('["alice","one"]')).toString(),
      );
      expect(sent, isEmpty);
      await repository.publish(
        operationId: 'one',
        snapshot: snapshot,
        nutritionVisible: true,
        isRecipe: false,
      );
      await SocialQueueRunner(store: store, transport: client).flush();
      expect(sent, hasLength(1));
      expect(sent.single['snapshot'].toString(), isNot(contains('private')));
    });
    test('prioritized cancellation with proof of the unpublished operation',
        () async {
      final postId = (await repository.publish(
        operationId: 'one',
        snapshot: snapshot,
        nutritionVisible: true,
        isRecipe: false,
      ))
          .value;
      await repository.deletePost(postId);
      await SocialQueueRunner(store: store, transport: client).flush();
      expect(sent, hasLength(1));
      expect(sent.single['action'], 'deletePost');
      expect(sent.single['operationId'], 'one');
      expect(sent.single['postId'], postId);
    });
    test('decoded recipe feed and cached only for the current account',
        () async {
      feed = {
        'posts': [
          {
            'id': 'one',
            'authorId': 'bob',
            'kind': 'recipe',
            'snapshot': snapshot.toJson(nutritionVisible: true),
            'nutritionVisible': true,
            'revision': 1,
            'publishedAt': 1791374400000,
            'caption': 'Dinner',
          }
        ],
        'cursor': {'id': 'one', 'publishedAt': 1791374400000},
      };
      final page = (await repository.fetchFeed()).value;
      expect(page.posts.single.isRecipe, isTrue);
      expect(page.cursor!.publishedAt.millisecondsSinceEpoch, 1791374400000);
      expect((await repository.cachedFeed()).single.id, 'one');
      await repository.signOut();
      expect(await repository.cachedFeed(), isEmpty);
    });
    test('replaced revoked content on an empty refresh', () async {
      final session = await store.session();
      await store.cacheFeed(
        session,
        [
          {'id': 'old'},
        ],
        DateTime.now(),
      );
      expect((await repository.fetchFeed()).isSuccess, isTrue);
      expect(await store.cachedFeed(session), isEmpty);
    });
    test('queued an owner edit with its revision and rejected another owner',
        () async {
      SocialPost post(String author) => SocialPost(
            id: 'post',
            authorId: author,
            snapshot: snapshot,
            nutritionVisible: true,
            revision: 3,
            publishedAt: DateTime(2026),
          );
      expect(
          (await repository.editPost(
            post: post('bob'),
            operationId: 'other',
            snapshot: snapshot,
            nutritionVisible: true,
          ))
              .isFailure,
          isTrue,);
      expect(
          (await repository.editPost(
            post: post('alice'),
            operationId: 'edit',
            snapshot: snapshot,
            nutritionVisible: false,
            caption: 'Updated dinner',
          ))
              .isSuccess,
          isTrue,);
      final command =
          await store.nextCommand(await store.session(), DateTime.now());
      expect(command!.action, 'editPost');
      expect(command.payload['baseRevision'], 3);
      expect(
          command.payload['snapshot'].toString(), isNot(contains('calories')),);
      expect(
          command.payload['snapshot'].toString(), isNot(contains('private')),);
    });

    test('hid queued deletions from both server responses and old cached posts',
        () async {
      feed = {
        'posts': [
          {
            'id': 'post',
            'authorId': 'alice',
            'kind': 'meal',
            'snapshot': snapshot.toJson(nutritionVisible: true),
            'nutritionVisible': true,
            'revision': 1,
            'publishedAt': 1791374400000,
          }
        ],
        'cursor': null,
      };
      expect((await repository.fetchFeed()).value.posts, hasLength(1));
      final session = await store.session();
      final oldCache = await store.cachedFeed(session);
      expect((await repository.deletePost('post')).isSuccess, isTrue);
      await store.cacheFeed(session, oldCache, DateTime.now());
      expect(await repository.cachedFeed(), isEmpty);
      expect((await repository.fetchFeed()).value.posts, isEmpty);
      expect(await store.cachedFeed(session), isEmpty);
      await store.switchAccount('bob');
      expect(await store.pendingDeletionTargets(session), isEmpty);
    });

    test('rejected attempts to publish unavailable nutrition', () async {
      final hidden = SocialSnapshot.fromJson(
        snapshot.toJson(nutritionVisible: false),
        nutritionVisible: false,
      );
      expect(
        (await repository.publish(
          operationId: 'one',
          snapshot: hidden,
          nutritionVisible: true,
          isRecipe: false,
        ))
            .isFailure,
        isTrue,
      );
      expect(
        await store.nextCommand(await store.session(), DateTime.now()),
        isNull,
      );
    });
  });
}
