import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'log_service.dart';

/// Service for handling local push notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Notification ID Ranges:
  // 0-99: Meal reminders (breakfast, lunch, dinner, custom meals)
  // 100-199: Supplement reminders
  // 200+: Reserved for future features

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
    _initialized = true;
  }

  /// Request permissions (iOS)
  Future<bool> requestPermissions() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Schedule a daily meal reminder
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
      // If the time has passed today, schedule for tomorrow
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'meal_reminders',
          'Meal Reminders',
          channelDescription: 'Reminders to log your meals',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
    );

    Log.info(
        'Scheduled notification $id at $hour:${minute.toString().padLeft(2, '0')}');
  }

  /// Cancel a specific reminder
  Future<void> cancelReminder(int id) async {
    await _notifications.cancel(id);
    Log.debug('Cancelled notification $id');
  }

  /// Cancel all reminders
  Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
    Log.debug('Cancelled all notifications');
  }

  /// Schedule all meal reminders based on settings
  Future<void> updateMealReminders({
    required bool enabled,
    String? breakfastTime,
    String? lunchTime,
    String? dinnerTime,
  }) async {
    // Cancel all existing reminders first
    await cancelReminder(0); // Breakfast
    await cancelReminder(1); // Lunch
    await cancelReminder(2); // Dinner

    if (!enabled) return;

    if (breakfastTime != null) {
      final parts = breakfastTime.split(':');
      await scheduleMealReminder(
        id: 0,
        title: 'Time for Breakfast! 🍳',
        body: 'Don\'t forget to log your breakfast',
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    if (lunchTime != null) {
      final parts = lunchTime.split(':');
      await scheduleMealReminder(
        id: 1,
        title: 'Time for Lunch! 🥗',
        body: 'Don\'t forget to log your lunch',
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    if (dinnerTime != null) {
      final parts = dinnerTime.split(':');
      await scheduleMealReminder(
        id: 2,
        title: 'Time for Dinner! 🍽️',
        body: 'Don\'t forget to log your dinner',
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }
  }
}
