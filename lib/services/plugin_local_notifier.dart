import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:sophis/services/local_notifier.dart';

/// Production [LocalNotifier] that delegates to the
/// `flutter_local_notifications` plugin.
///
/// All platform-specific concerns (Android channels, iOS presentation
/// options, exact-alarm schedule mode, daily-repeat components) live
/// here so that [NotificationService] and any future caller can stay
/// platform-agnostic.
class PluginLocalNotifier implements LocalNotifier {
  static const _mealChannelId = 'meal_reminders';
  static const _mealChannelName = 'Meal Reminders';
  static const _mealChannelDescription = 'Reminders to log your meals';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

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

    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  @override
  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  @override
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _mealChannelId,
          _mealChannelName,
          channelDescription: _mealChannelDescription,
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
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _plugin.cancel(id: id);
  }

  @override
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
