import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/social_callable_client.dart';

final class PartnerConnection {
  final String id;
  final String displayName;
  final String otherId;
  final String inviterId;
  final bool accepted;
  final Map<String, dynamic> ownSettings;
  final Map<String, dynamic> otherSettings;

  PartnerConnection.fromJson(Map<String, dynamic> data, String uid)
      : id = data['id'] as String,
        displayName = data['displayName'] as String,
        otherId = (data['participants'] as List)
            .cast<String>()
            .firstWhere((id) => id != uid),
        inviterId = data['inviterId'] as String,
        accepted = data['status'] == 'accepted',
        ownSettings = Map.unmodifiable(
          _sharingSettings((data['settings'] as Map)[uid] as Map),
        ),
        otherSettings = Map.unmodifiable(
          _sharingSettings(
            (data['settings'] as Map)[(data['participants'] as List)
                .firstWhere((id) => id != uid)] as Map,
          ),
        );

  static Map<String, dynamic> _sharingSettings(Map settings) => {
        ...Map<String, dynamic>.from(settings),
        'meals': true,
        'summaries': true,
        'goals': true,
        'photos': settings['photos'] == true,
        'paused': false,
        'mealPeriods': [
          {'start': 0, 'end': null},
        ],
        'summaryPeriods': [
          {'start': 0, 'end': null},
        ],
      };
}

/// Partner reads are online and use captured account tokens.
final class SocialPartnerRepository {
  final SocialClient client;
  SocialPartnerRepository(this.client);

  Future<ServiceResult<Map<String, dynamic>>> request(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final session = await client.captureSession();
    if (session == null) {
      return const Failure(
        ServiceErrorType.authFailed,
        'Your account changed.',
      );
    }
    final result = await client.call(session, action, payload);
    return switch (result) {
      Success<Object?>(:final value) when value is Map<String, dynamic> =>
        Success(value),
      Failure<Object?>(:final errorType, :final message) =>
        Failure(errorType, message),
      _ => const Failure(
          ServiceErrorType.parseError,
          'Could not read partner information.',
        ),
    };
  }

  Future<ServiceResult<List<PartnerConnection>>> connections() async {
    final uid = client.accountId;
    final result = await request('partners', {});
    if (result is Failure<Map<String, dynamic>>) {
      return Failure(result.errorType, result.message);
    }
    try {
      return Success(
        (result.value['connections'] as List)
            .map(
              (raw) =>
                  PartnerConnection.fromJson(raw as Map<String, dynamic>, uid!),
            )
            .toList(),
      );
    } catch (_) {
      return const Failure(
        ServiceErrorType.parseError,
        'Could not read partner connections.',
      );
    }
  }

  Future<ServiceResult<Map<String, dynamic>>> settings(
    PartnerConnection connection,
    String field,
    bool value,
  ) =>
      request('partnerSettings', {
        'connectionId': connection.id,
        'baseRevision': connection.ownSettings['revision'],
        for (final key in ['meals', 'summaries', 'photos', 'goals', 'paused'])
          key: key == field ? value : connection.ownSettings[key] == true,
      });
}
