import 'package:timezone/timezone.dart' as tz;

import 'package:sophis/services/local_notifier.dart';
import 'package:sophis/services/plugin_local_notifier.dart';
import 'package:sophis/utils/time_utils.dart';

/// Service for handling local push notifications.
///
/// Holds business logic (parsing stored times, deciding whether a
/// reminder should land today or tomorrow, picking reminder copy) and
/// delegates the actual scheduling to an injected [LocalNotifier].
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Convenience constructor for tests and DI: build a service backed
  /// by a caller-supplied [LocalNotifier] (typically a fake or a
  /// recording implementation).
  NotificationService.withNotifier(LocalNotifier notifier)
      : _notifier = notifier;

  LocalNotifier _notifier = PluginLocalNotifier();

  /// Replaces the underlying notifier. Intended for tests; production
  /// code should use [NotificationService.withNotifier] at construction
  /// time instead.
  set notifier(LocalNotifier value) => _notifier = value;

  // Notification ID Ranges:
  // 0-99: Meal reminders (breakfast, lunch, dinner, custom meals)
  // 100-199: Supplement reminders
  // 200+: Reserved for future features

  /// Initialize the notification service.
  Future<void> initialize() async {
    await _notifier.initialize();
  }

  /// Request permissions (iOS / Android 13+).
  Future<bool> requestPermissions() async {
    return _notifier.requestPermissions();
  }

  /// Schedule a daily meal reminder.
  Future<void> scheduleMealReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    bool startTomorrow = false,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (startTomorrow) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    } else if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifier.scheduleAt(
      id: id,
      title: title,
      body: body,
      when: scheduledDate,
    );
  }

  /// Cancel a specific reminder.
  Future<void> cancelReminder(int id) async {
    await _notifier.cancel(id);
  }

  /// Cancel all reminders.
  Future<void> cancelAllReminders() async {
    await _notifier.cancelAll();
  }

  /// Schedule all meal reminders based on settings.
  Future<void> updateMealReminders({
    required bool enabled,
    String? breakfastTime,
    String? lunchTime,
    String? dinnerTime,
  }) async {
    await cancelReminder(0);
    await cancelReminder(1);
    await cancelReminder(2);

    if (!enabled) return;

    final breakfast = TimeUtils.parseStoredTime(breakfastTime);
    if (breakfast != null) {
      await scheduleMealReminder(
        id: 0,
        title: 'Time for Breakfast! 🍳',
        body: 'Don\'t forget to log your breakfast',
        hour: breakfast.hour,
        minute: breakfast.minute,
      );
    }

    final lunch = TimeUtils.parseStoredTime(lunchTime);
    if (lunch != null) {
      await scheduleMealReminder(
        id: 1,
        title: 'Time for Lunch! 🥗',
        body: 'Don\'t forget to log your lunch',
        hour: lunch.hour,
        minute: lunch.minute,
      );
    }

    final dinner = TimeUtils.parseStoredTime(dinnerTime);
    if (dinner != null) {
      await scheduleMealReminder(
        id: 2,
        title: 'Time for Dinner! 🍽️',
        body: 'Don\'t forget to log your dinner',
        hour: dinner.hour,
        minute: dinner.minute,
      );
    }
  }
}
