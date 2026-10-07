import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/social_local_store.dart';
import 'package:sophis/services/social/social_queue_runner.dart';

/// Credentials are captured for the requested account, never substituted after
/// token refresh. Implementations must reject a changed authentication epoch.
abstract interface class SocialCredentials {
  String? get accountId;
  Future<SocialTokens> tokensFor(String accountId);
}

final class SocialCredentialFailure implements Exception {
  final ServiceErrorType errorType;
  const SocialCredentialFailure(this.errorType);
}

final class SocialTokens {
  final String accountId;
  final String idToken;
  final String? appCheckToken;

  const SocialTokens({
    required this.accountId,
    required this.idToken,
    this.appCheckToken,
  });
}

/// Implements Firebase's documented callable protocol so each request uses the
/// captured user's token. A generic callable SDK can refresh the current user
/// after an account switch; that must not happen to durable queued commands.
final class SocialCallableClient implements SocialCommandTransport {
  final SocialCredentials credentials;
  final SocialLocalStore store;
  final Uri endpoint;
  final http.Client _http;
  final bool requireAppCheck;

  SocialCallableClient({
    required this.credentials,
    required this.store,
    required this.endpoint,
    required http.Client client,
    this.requireAppCheck = true,
  }) : _http = client {
    if (endpoint.scheme != 'https' &&
        !(endpoint.scheme == 'http' && !requireAppCheck)) {
      throw ArgumentError('Social endpoint requires HTTPS');
    }
  }

  @override
  String? get accountId => credentials.accountId;

  Future<ServiceResult<Object?>> call(
    SocialSession expected,
    String action,
    Map<String, dynamic> payload,
  ) async {
    if (payload.containsKey('accountId') ||
        payload.containsKey('authorId') ||
        payload.containsKey('action')) {
      return const Failure(
        ServiceErrorType.parseError,
        'Invalid social payload',
      );
    }
    try {
      if (!await _isCurrent(expected)) return _changed();
      final tokens = await credentials.tokensFor(expected.accountId!);
      if (tokens.accountId != expected.accountId ||
          tokens.idToken.isEmpty ||
          !await _isCurrent(expected)) {
        return _changed();
      }
      if (requireAppCheck &&
          (tokens.appCheckToken == null || tokens.appCheckToken!.isEmpty)) {
        return const Failure(
          ServiceErrorType.authFailed,
          'Could not verify this device. Try again.',
        );
      }
      final request = http.Request('POST', endpoint)
        ..followRedirects = false
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${tokens.idToken}',
          if (tokens.appCheckToken != null)
            'X-Firebase-AppCheck': tokens.appCheckToken!,
        })
        ..body = jsonEncode({
          'data': {...payload, 'action': action},
        });
      // Last check occurs after all asynchronous credential work. The request
      // carries that captured identity even if the app switches while in flight.
      if (!await _isCurrent(expected)) return _changed();
      final response =
          await _http.send(request).timeout(const Duration(seconds: 35));
      final bytes = <int>[];
      await for (final chunk
          in response.stream.timeout(const Duration(seconds: 35))) {
        bytes.addAll(chunk);
        if (bytes.length > 2 * 1024 * 1024) {
          return const Failure(
            ServiceErrorType.parseError,
            'Social response was too large',
          );
        }
      }
      if (!await _isCurrent(expected)) return _changed();
      final body = jsonDecode(utf8.decode(bytes));
      if (body is! Map<String, dynamic>) throw const FormatException();
      if (body['error'] != null) {
        final error = body['error'];
        if (error is! Map<String, dynamic>) throw const FormatException();
        return _failure(error['status'] as String?);
      }
      if (response.statusCode != 200 || !body.containsKey('result')) {
        return _failure(
          response.statusCode == 429 ? 'RESOURCE_EXHAUSTED' : 'UNAVAILABLE',
        );
      }
      return Success(body['result']);
    } on SocialCredentialFailure catch (error) {
      return Failure(
        error.errorType,
        'Could not refresh your session. Try again.',
      );
    } on TimeoutException {
      return const Failure(
        ServiceErrorType.network,
        'People is taking too long. Try again.',
      );
    } on http.ClientException {
      return const Failure(
        ServiceErrorType.network,
        'People is offline. Try again later.',
      );
    } on StateError {
      return _changed();
    } on FormatException {
      return const Failure(
        ServiceErrorType.parseError,
        'Could not read the social response.',
      );
    } catch (_) {
      return const Failure(
        ServiceErrorType.unknown,
        'Could not complete the social action.',
      );
    }
  }

  Future<bool> _isCurrent(SocialSession expected) async =>
      expected.accountId != null &&
      accountId == expected.accountId &&
      await store.isCurrent(expected);

  Failure<Object?> _changed() => const Failure(
        ServiceErrorType.authFailed,
        'Your account changed. Open People again.',
      );

  Failure<Object?> _failure(String? status) => switch (status) {
        'UNAUTHENTICATED' || 'PERMISSION_DENIED' => const Failure(
            ServiceErrorType.authFailed,
            'Sign in or refresh access to this content.',
          ),
        'RESOURCE_EXHAUSTED' => const Failure(
            ServiceErrorType.rateLimited,
            'Social usage limit reached. Try again later.',
          ),
        'NOT_FOUND' => const Failure(
            ServiceErrorType.notFound,
            'Content is no longer available.',
          ),
        'INVALID_ARGUMENT' ||
        'FAILED_PRECONDITION' ||
        'ABORTED' ||
        'ALREADY_EXISTS' =>
          const Failure(
            ServiceErrorType.parseError,
            'This action needs review. Refresh before trying again.',
          ),
        'UNAVAILABLE' || 'DEADLINE_EXCEEDED' || 'INTERNAL' => const Failure(
            ServiceErrorType.network,
            'People is temporarily unavailable. Try again later.',
          ),
        _ => const Failure(
            ServiceErrorType.unknown,
            'Could not complete the social action.',
          ),
      };

  @override
  Future<ServiceResult<void>> send(
    SocialSession session,
    SocialQueuedCommand command,
  ) async {
    final result = await call(session, command.action, command.payload);
    return switch (result) {
      Success<Object?>() => const Success(null),
      Failure<Object?>(:final errorType, :final message) =>
        Failure(errorType, message),
    };
  }
}
