import 'package:timezone/timezone.dart' as tz;

/// Platform-agnostic seam for scheduling local push notifications.
///
/// `NotificationService` depends on this abstraction so that tests can swap
/// in a recording or no-op implementation, and so the platform plugin
/// (currently `flutter_local_notifications`) stays confined to a single
/// adapter file. Adapters are responsible for timezone initialization,
/// platform permission requests, channel setup, and any
/// platform-specific scheduling mode flags.
abstract class LocalNotifier {
  Future<void> initialize();

  /// Requests notification permissions from the host OS.
  ///
  /// Returns `true` if permissions are granted (or not required on the
  /// current platform), `false` if the user denied the request.
  Future<bool> requestPermissions();

  /// Schedules a single notification at [when] with the given content.
  ///
  /// The id, title, and body are opaque to the notifier: callers manage
  /// their own id namespace.
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
  });

  /// Cancels the previously scheduled notification with the given id.
  Future<void> cancel(int id);

  /// Cancels every previously scheduled notification.
  Future<void> cancelAll();
}
