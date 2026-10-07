import 'package:sophis/models/social/social_snapshot.dart';
import 'package:sophis/services/service_result.dart';

final class SocialPost {
  final String id;
  final String authorId;
  final SocialSnapshot snapshot;
  final bool nutritionVisible;
  final int revision;
  final DateTime publishedAt;
  final String? caption;
  final String? photoBlobId;

  const SocialPost({
    required this.id,
    required this.authorId,
    required this.snapshot,
    required this.nutritionVisible,
    required this.revision,
    required this.publishedAt,
    this.caption,
    this.photoBlobId,
  });
}

final class SocialFeedCursor {
  final String id;
  final DateTime publishedAt;

  const SocialFeedCursor({required this.id, required this.publishedAt});
}

final class SocialFeedPage {
  final List<SocialPost> posts;
  final SocialFeedCursor? cursor;

  SocialFeedPage({required List<SocialPost> posts, this.cursor})
      : posts = List.unmodifiable(posts);
}

/// Firebase transport stays behind this seam. Guest tracking does not depend on
/// authentication or social initialization. No NutritionStore outbox is exposed.
abstract interface class SocialRepository {
  String? get accountId;
  Future<ServiceResult<SocialFeedPage>> fetchFeed({SocialFeedCursor? cursor});
  Future<ServiceResult<String>> publish({
    required String operationId,
    required SocialSnapshot snapshot,
    required bool nutritionVisible,
    required bool isRecipe,
    String? caption,
    String? photoBlobId,
  });
  Future<ServiceResult<void>> deletePost(String postId);
  Future<ServiceResult<void>> react(String postId, String? kind);
  Future<ServiceResult<void>> removeFollower(String accountId);
  Future<ServiceResult<void>> unfollow(String accountId);
  Future<ServiceResult<void>> block(String accountId);

  /// Must discard account-specific cache and durable queue before returning.
  Future<ServiceResult<void>> signOut();
}
