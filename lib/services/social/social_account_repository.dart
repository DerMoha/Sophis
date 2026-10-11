import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/social_callable_client.dart';
import 'package:sophis/services/social/social_local_store.dart';

final class SocialProfile {
  final String accountId;
  final String displayName;
  const SocialProfile({required this.accountId, required this.displayName});
}

final class SocialInvitation {
  final String token;
  final DateTime expiresAt;
  final String audience;
  const SocialInvitation({
    required this.token,
    required this.expiresAt,
    required this.audience,
  });
  Uri get link => Uri(
        scheme: 'sophis',
        host: 'people',
        path: '/invite',
        queryParameters: {'token': token},
      );
}

final class SocialInvitationPreview {
  final String accountId;
  final String displayName;
  final String audience;
  final DateTime expiresAt;
  const SocialInvitationPreview({
    required this.accountId,
    required this.displayName,
    required this.audience,
    required this.expiresAt,
  });
}

final class SocialRelationship {
  final String accountId;
  final String displayName;
  final String status;
  final String? reciprocalStatus;
  const SocialRelationship({
    required this.accountId,
    required this.displayName,
    required this.status,
    this.reciprocalStatus,
  });
}

final class SocialRelationshipPage {
  final List<SocialRelationship> relationships;
  final Map<String, dynamic>? cursor;
  SocialRelationshipPage({
    required List<SocialRelationship> relationships,
    this.cursor,
  }) : relationships = List.unmodifiable(relationships);
}

final class SocialAccountRepository {
  final SocialClient client;
  final SocialLocalStore store;
  SocialAccountRepository({required this.client, required this.store});

  Future<ServiceResult<T>> _request<T>(
    String action,
    Map<String, dynamic> payload,
    T Function(Map<String, dynamic>) decode,
  ) async {
    try {
      final session = await client.captureSession();
      if (session == null) {
        return const Failure(
          ServiceErrorType.authFailed,
          'Your account changed.',
        );
      }
      final result = await client.call(session, action, payload);
      return switch (result) {
        Success<Object?>(:final value) =>
          Success(decode(value as Map<String, dynamic>)),
        Failure<Object?>(:final errorType, :final message) =>
          Failure(errorType, message),
      };
    } catch (_) {
      return const Failure(
        ServiceErrorType.parseError,
        'Could not read account information. Try again.',
      );
    }
  }

  Future<ServiceResult<SocialProfile?>> profile() =>
      _request('ownProfile', {}, (data) {
        final profile = data['profile'] as Map<String, dynamic>?;
        return profile == null
            ? null
            : SocialProfile(
                accountId: profile['accountId'] as String,
                displayName: profile['displayName'] as String,
              );
      });
  Future<ServiceResult<SocialProfile>> saveProfile(String name) => _request(
        'setProfile',
        {'displayName': name.trim()},
        (data) => SocialProfile(
          accountId: data['accountId'] as String,
          displayName: data['displayName'] as String,
        ),
      );
  Future<ServiceResult<SocialInvitation>> invite(String audience) => _request(
        'createInvitation',
        {'audience': audience},
        (data) => SocialInvitation(
          token: data['token'] as String,
          audience: audience,
          expiresAt: _date(data['expiresAt']),
        ),
      );
  Future<ServiceResult<SocialInvitationPreview>> preview(String token) =>
      _request(
        'previewInvitation',
        {'token': token},
        (data) => SocialInvitationPreview(
          accountId: data['inviterId'] as String,
          displayName: data['displayName'] as String,
          audience: data['audience'] as String,
          expiresAt: _date(data['expiresAt']),
        ),
      );
  Future<ServiceResult<SocialRelationshipPage>> relationships(
    String direction, {
    Map<String, dynamic>? cursor,
  }) =>
      _request(
        'relationships',
        {'direction': direction, if (cursor != null) 'cursor': cursor},
        (data) => SocialRelationshipPage(
          relationships: (data['relationships'] as List).map((raw) {
            final value = raw as Map<String, dynamic>;
            return SocialRelationship(
              accountId: value['accountId'] as String,
              displayName: value['displayName'] as String,
              status: value['status'] as String,
              reciprocalStatus: value['reciprocalStatus'] as String?,
            );
          }).toList(),
          cursor: data['cursor'] as Map<String, dynamic>?,
        ),
      );
  Future<ServiceResult<void>> approve(String accountId) =>
      _request('approveFollow', {'followerId': accountId}, (_) {});
  Future<ServiceResult<void>> requestReciprocal(String accountId) =>
      _request('requestReciprocal', {'otherId': accountId}, (_) {});
  Future<ServiceResult<void>> request(
    SocialInvitationPreview preview,
    String token,
  ) =>
      _request(
        preview.audience == 'partner' ? 'requestPartner' : 'requestFollow',
        {'token': token},
        (_) {},
      );
  Future<ServiceResult<void>> revoke(String token) =>
      _request('revokeInvitation', {'token': token}, (_) {});
  DateTime _date(Object? value) =>
      DateTime.fromMillisecondsSinceEpoch((value as num).toInt(), isUtc: true);
}
