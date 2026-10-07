import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/social_local_store.dart';

/// Implement with Firebase callable functions. The adapter must capture/recheck
/// the authenticated UID when obtaining credentials, rather than using whichever
/// account happens to be signed in after an asynchronous token refresh.
abstract interface class SocialCommandTransport {
  String? get accountId;
  Future<ServiceResult<void>> send(
    SocialSession session,
    SocialQueuedCommand command,
  );
}

final class SocialQueueRunner {
  final SocialLocalStore store;
  final SocialCommandTransport transport;
  bool _running = false;

  SocialQueueRunner({required this.store, required this.transport});

  /// Returns false after a failure so automatic drains stop immediately.
  /// Bounded work on app resume/connectivity restoration. No unbounded listener
  /// or tight retry loop. The caller displays persisted queued/review status.
  Future<bool> flush({DateTime? now, int limit = 20}) async {
    if (_running) return false;
    _running = true;
    try {
      final session = await store.session();
      if (session.accountId == null) return false;
      final clock = now ?? DateTime.now();
      for (var index = 0; index < limit; index++) {
        if (transport.accountId != session.accountId ||
            !await store.isCurrent(session)) {
          return false;
        }
        final command = await store.nextCommand(session, clock);
        if (command == null) return true;
        if (transport.accountId != session.accountId ||
            !await store.isCurrent(session)) {
          return false;
        }
        final result = await transport.send(session, command);
        if (!await store.isCurrent(session)) return false;
        if (result is Success<void>) {
          await store.acknowledge(session, command.operationId);
        } else {
          final failure = result as Failure<void>;
          await store.retry(
            session,
            command,
            clock,
            requiresReview: failure.errorType != ServiceErrorType.network &&
                failure.errorType != ServiceErrorType.rateLimited,
          );
          return false;
        }
      }
      return true;
    } finally {
      _running = false;
    }
  }
}
