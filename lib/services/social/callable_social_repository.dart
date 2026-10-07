import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sophis/models/social/social_snapshot.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/social_callable_client.dart';
import 'package:sophis/services/social/social_local_store.dart';
import 'package:sophis/services/social/social_repository.dart';
import 'package:uuid/uuid.dart';

/// Screens receive domain data; all wire encoding and durable publication stay
/// here. Published snapshots and imported private diary copies are independent.
final class CallableSocialRepository implements SocialRepository {
  final SocialCallableClient client;
  final SocialLocalStore store;
  final Future<ServiceResult<void>> Function() _signOut;
  final Uuid _uuid;

  CallableSocialRepository({
    required this.client,
    required this.store,
    required Future<ServiceResult<void>> Function() signOut,
    Uuid uuid = const Uuid(),
  })  : _signOut = signOut,
        _uuid = uuid;

  @override
  String? get accountId => client.accountId;

  @override
  Future<ServiceResult<SocialFeedPage>> fetchFeed({
    SocialFeedCursor? cursor,
  }) async {
    final session = await store.session();
    final result = await client.call(session, 'feed', {
      if (cursor != null)
        'cursor': {
          'id': cursor.id,
          'publishedAt': cursor.publishedAt.millisecondsSinceEpoch,
        },
    });
    if (result is Failure<Object?>) {
      if (result.errorType == ServiceErrorType.authFailed) {
        await store.clearCache(expected: session);
      }
      return Failure(result.errorType, result.message);
    }
    try {
      final data = result.value as Map<String, dynamic>;
      final received = (data['posts'] as List).cast<Map<String, dynamic>>();
      if (received.length > 20) throw const FormatException();
      final deleting = await store.pendingDeletionTargets(session);
      final raw =
          received.where((post) => !deleting.contains(post['id'])).toList();
      final posts = raw.map(_post).toList();
      final next = data['cursor'] as Map<String, dynamic>?;
      final page = SocialFeedPage(
        posts: posts,
        cursor: next == null
            ? null
            : SocialFeedCursor(
                id: next['id'] as String,
                publishedAt: _date(next['publishedAt']),
              ),
      );
      if (cursor == null) await store.cacheFeed(session, raw, DateTime.now());
      if (!await store.isCurrent(session) || accountId != session.accountId) {
        return const Failure(
          ServiceErrorType.authFailed,
          'Your account changed.',
        );
      }
      return Success(page);
    } catch (_) {
      return const Failure(
        ServiceErrorType.parseError,
        'Could not read the feed. Refresh and try again.',
      );
    }
  }

  Future<List<SocialPost>> cachedFeed() async {
    final session = await store.session();
    if (session.accountId != accountId) return [];
    final raw = await store.cachedFeed(session);
    try {
      final deleting = await store.pendingDeletionTargets(session);
      final posts = raw
          .where((post) => !deleting.contains(post['id']))
          .map(_post)
          .toList();
      if (!await store.isCurrent(session) || session.accountId != accountId) {
        return [];
      }
      return posts;
    } catch (_) {
      await store.clearCache(expected: session);
      return [];
    }
  }

  SocialPost _post(Map<String, dynamic> value) {
    final visible = value['nutritionVisible'] as bool;
    final kind = value['kind'];
    if (kind != 'meal' && kind != 'recipe') throw const FormatException();
    return SocialPost(
      id: value['id'] as String,
      authorId: value['authorId'] as String,
      snapshot: SocialSnapshot.fromJson(
        value['snapshot'] as Map<String, dynamic>,
        nutritionVisible: visible,
      ),
      nutritionVisible: visible,
      revision: (value['revision'] as num).toInt(),
      isRecipe: kind == 'recipe',
      publishedAt: _date(value['publishedAt']),
      caption: value['caption'] as String?,
      photoBlobId: value['photoBlobId'] as String?,
    );
  }

  DateTime _date(Object? milliseconds) => DateTime.fromMillisecondsSinceEpoch(
        (milliseconds as num).toInt(),
        isUtc: true,
      );

  @override
  Future<ServiceResult<String>> publish({
    required String operationId,
    required SocialSnapshot snapshot,
    required bool nutritionVisible,
    required bool isRecipe,
    String? caption,
    String? photoBlobId,
  }) async {
    final session = await store.session();
    final uid = session.accountId;
    if (uid == null || accountId != uid) {
      return const Failure(ServiceErrorType.authFailed, 'Sign in to publish.');
    }
    if (nutritionVisible && !snapshot.nutritionAvailable) {
      return const Failure(
        ServiceErrorType.parseError,
        'Nutrition is unavailable for this meal.',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(operationId)) {
      return const Failure(
        ServiceErrorType.parseError,
        'Invalid publication operation.',
      );
    }
    final postId =
        sha256.convert(utf8.encode(jsonEncode([uid, operationId]))).toString();
    final result = await _enqueue(
      session,
      SocialQueuedCommand(
        operationId: operationId,
        action: 'publish',
        targetId: postId,
        payload: {
          'operationId': operationId,
          'kind': isRecipe ? 'recipe' : 'meal',
          'snapshot': snapshot.toJson(nutritionVisible: nutritionVisible),
          'nutritionVisible': nutritionVisible,
          'caption': caption?.trim().isEmpty == true ? null : caption,
          'photoBlobId': photoBlobId,
        },
        createdAt: DateTime.now(),
      ),
    );
    return switch (result) {
      Success<void>() => Success(postId),
      Failure<void>(:final errorType, :final message) =>
        Failure(errorType, message),
    };
  }

  @override
  Future<ServiceResult<void>> deletePost(String postId) async {
    final session = await store.session();
    final publication =
        await store.pendingPublicationOperation(session, postId);
    await store.clearCache(expected: session);
    return _enqueue(
      session,
      SocialQueuedCommand(
        operationId: _uuid.v4(),
        action: 'deletePost',
        targetId: postId,
        payload: {
          'postId': postId,
          if (publication != null) 'operationId': publication,
        },
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<ServiceResult<void>> editPost({
    required SocialPost post,
    required String operationId,
    required SocialSnapshot snapshot,
    required bool nutritionVisible,
    String? caption,
  }) async {
    if (post.authorId != accountId) {
      return const Failure(
          ServiceErrorType.authFailed, 'Only the author can edit.',);
    }
    if (nutritionVisible && !snapshot.nutritionAvailable) {
      return const Failure(
          ServiceErrorType.parseError, 'Nutrition is unavailable.',);
    }
    return _enqueue(
      await store.session(),
      SocialQueuedCommand(
        operationId: operationId,
        action: 'editPost',
        targetId: post.id,
        payload: {
          'postId': post.id,
          'baseRevision': post.revision,
          'snapshot': snapshot.toJson(nutritionVisible: nutritionVisible),
          'nutritionVisible': nutritionVisible,
          'caption': caption?.trim().isEmpty == true ? null : caption,
        },
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<ServiceResult<void>> react(String postId, String? kind) async =>
      _enqueue(
        await store.session(),
        SocialQueuedCommand(
          operationId: _uuid.v4(),
          action: 'react',
          targetId: postId,
          payload: {'postId': postId, 'kind': kind},
          createdAt: DateTime.now(),
        ),
      );

  Future<ServiceResult<void>> _enqueue(
    SocialSession session,
    SocialQueuedCommand command,
  ) async {
    try {
      if (session.accountId == null || session.accountId != accountId) {
        return const Failure(
          ServiceErrorType.authFailed,
          'Sign in to use People.',
        );
      }
      await store.enqueue(session, command);
      if (!await store.isCurrent(session) || session.accountId != accountId) {
        return const Failure(
          ServiceErrorType.authFailed,
          'Your account changed.',
        );
      }
      return const Success(null);
    } catch (_) {
      return const Failure(
        ServiceErrorType.unknown,
        'Could not save this social action.',
      );
    }
  }

  Future<ServiceResult<void>> _relationship(
    String action,
    String otherId,
  ) async {
    final session = await store.session();
    await store.clearCache(expected: session);
    final result = await client.call(session, action, {'otherId': otherId});
    return switch (result) {
      Success<Object?>() => const Success(null),
      Failure<Object?>(:final errorType, :final message) =>
        Failure(errorType, message),
    };
  }

  @override
  Future<ServiceResult<void>> removeFollower(String accountId) =>
      _relationship('removeFollower', accountId);
  @override
  Future<ServiceResult<void>> unfollow(String accountId) =>
      _relationship('unfollow', accountId);
  @override
  Future<ServiceResult<void>> block(String accountId) =>
      _relationship('block', accountId);
  @override
  Future<ServiceResult<void>> signOut() => _signOut();
}
