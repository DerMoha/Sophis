import 'dart:async';
import 'dart:convert';

import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/social_callable_client.dart';
import 'package:sophis/services/social/social_local_store.dart';

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

/// Online reads refresh an account-scoped, bounded cache for immediate display.
final class SocialPartnerRepository {
  final SocialClient client;
  final SocialLocalStore? store;
  final Map<String, int> _readVersions = {};
  int _nextReadVersion = 0;
  SocialPartnerRepository(this.client, {this.store});

  static const _cachedActions = {
    'partners',
    'partnerGoals',
    'partnerSummaries',
    'partnerMeals',
  };

  String _cacheKey(String action, Map<String, dynamic> payload) {
    if (action == 'partners') return action;
    Object? canonical(Object? value) {
      if (value is Map) {
        return {
          for (final key in value.keys.cast<String>().toList()..sort())
            key: canonical(value[key]),
        };
      }
      if (value is List) return value.map(canonical).toList();
      return value;
    }

    return '$action:${jsonEncode(canonical(payload))}';
  }

  Future<SocialCachedResponse?> cached(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final local = store;
    if (local == null || !_cachedActions.contains(action)) return null;
    final session = await client.captureSession();
    if (session == null) return null;
    return local.partnerCache(session, _cacheKey(action, payload));
  }

  Future<List<PartnerConnection>?> cachedConnections() async {
    final uid = client.accountId;
    final response = await cached('partners', {});
    if (response == null || uid == null || client.accountId != uid) return null;
    return _decodeConnections(response.data, uid);
  }

  List<PartnerConnection> _decodeConnections(
    Map<String, dynamic> data,
    String uid,
  ) =>
      (data['connections'] as List)
          .map(
            (raw) =>
                PartnerConnection.fromJson(raw as Map<String, dynamic>, uid),
          )
          .toList();

  void _validate(String action, Map<String, dynamic> data, String uid) {
    if (action == 'partners') {
      _decodeConnections(data, uid);
    } else {
      final field = switch (action) {
        'partnerGoals' => 'goals',
        'partnerSummaries' => 'summaries',
        _ => 'meals',
      };
      (data[field] as List).cast<Map<String, dynamic>>().toList();
    }
  }

  Future<ServiceResult<Map<String, dynamic>>> request(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final key = _cacheKey(action, payload);
    final version = ++_nextReadVersion;
    _readVersions[key] = version;
    try {
      final session = await client.captureSession();
      if (session == null) {
        return const Failure(
          ServiceErrorType.authFailed,
          'Your account changed.',
        );
      }
      final connectionId = payload['connectionId'] as String?;
      final connectionState = connectionId == null
          ? null
          : await store?.cachedConnectionState(session, connectionId);
      final result = await client.call(session, action, payload);
      if (store != null && !await store!.isCurrent(session)) {
        return const Failure(
          ServiceErrorType.authFailed,
          'Your account changed.',
        );
      }
      if (connectionState != null &&
          _cachedActions.contains(action) &&
          await store?.cachedConnectionState(session, connectionId!) !=
              connectionState) {
        return const Failure(
          ServiceErrorType.authFailed,
          'Sharing permission changed. Refresh and try again.',
        );
      }
      if (result is Success<Object?> && result.value is Map<String, dynamic>) {
        final data = result.value as Map<String, dynamic>;
        if (_cachedActions.contains(action)) {
          _validate(action, data, session.accountId!);
          if (_readVersions[key] == version) {
            await store?.cachePartnerResponse(
              session,
              _cacheKey(action, payload),
              data,
              connectionId: connectionId,
              connectionState: connectionState,
            );
          }
        } else if (action == 'disconnectPartner' && connectionId != null) {
          await store?.clearPartnerCache(session, connectionId: connectionId);
        }
      } else if (result is Failure<Object?> &&
          (result.errorType == ServiceErrorType.authFailed ||
              result.errorType == ServiceErrorType.notFound)) {
        if (_readVersions[key] == version) {
          await store?.clearPartnerCache(session, connectionId: connectionId);
        }
      }
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
    } on TimeoutException {
      return const Failure(
        ServiceErrorType.network,
        'Partner sharing timed out. Try again.',
      );
    } catch (_) {
      return const Failure(
        ServiceErrorType.unknown,
        'Could not complete partner sharing. Refresh and try again.',
      );
    } finally {
      if (_readVersions[key] == version) _readVersions.remove(key);
    }
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
