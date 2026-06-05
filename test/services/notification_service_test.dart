import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:sophis/services/local_notifier.dart';
import 'package:sophis/services/notification_service.dart';

typedef _Scheduled = ({int id, String title, String body, tz.TZDateTime when});

/// Base class for test adapters: records the contract surface so
/// tests can assert against it without leaking implementation details.
abstract class _TestNotifier implements LocalNotifier {
  int initializeCount = 0;
  int requestPermissionsCount = 0;
  int cancelAllCount = 0;
  final List<int> canceledIds = [];
  final List<_Scheduled> scheduled = [];
  bool permissionsGranted = true;

  void reset();

  @override
  Future<void> initialize() async {
    initializeCount++;
  }

  @override
  Future<bool> requestPermissions() async {
    requestPermissionsCount++;
    return permissionsGranted;
  }

  @override
  Future<void> cancel(int id) async {
    canceledIds.add(id);
    scheduled.removeWhere((entry) => entry.id == id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
    scheduled.clear();
  }
}

/// Records every call and replaces a prior schedule for the same id
/// (matches the platform plugin's "schedule replaces schedule"
/// semantics).
class RecordingLocalNotifier extends _TestNotifier {
  @override
  void reset() {
    initializeCount = 0;
    requestPermissionsCount = 0;
    cancelAllCount = 0;
    canceledIds.clear();
    scheduled.clear();
    permissionsGranted = true;
  }

  @override
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
  }) async {
    scheduled.removeWhere((entry) => entry.id == id);
    scheduled.add((id: id, title: title, body: body, when: when));
  }
}

/// A second implementation that uses a Set to track live ids and
/// mutates the scheduled list differently. Same contract, different
/// code path — proves the service doesn't depend on implementation
/// details of the recording adapter.
class InMemoryLocalNotifier extends _TestNotifier {
  final Set<int> _liveIds = {};

  @override
  void reset() {
    initializeCount = 0;
    requestPermissionsCount = 0;
    cancelAllCount = 0;
    canceledIds.clear();
    scheduled.clear();
    _liveIds.clear();
    permissionsGranted = true;
  }

  @override
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
  }) async {
    if (_liveIds.add(id)) {
      // newly added
    } else {
      scheduled.removeWhere((entry) => entry.id == id);
    }
    scheduled.add((id: id, title: title, body: body, when: when));
  }
}

/// Wraps a factory and a name so the contract tests can be parameterised
/// over both adapters with a single body.
class _AdapterCase {
  _AdapterCase(this.name, this.factory);

  final String name;
  final _TestNotifier Function() factory;

  late _TestNotifier notifier;

  void reset() {
    notifier = factory();
  }
}

List<_AdapterCase> _cases() => [
      _AdapterCase('RecordingLocalNotifier', RecordingLocalNotifier.new),
      _AdapterCase('InMemoryLocalNotifier', InMemoryLocalNotifier.new),
    ];

void main() {
  tz_data.initializeTimeZones();

  final cases = _cases();

  for (final adapter in cases) {
    group('NotificationService via ${adapter.name}', () {
      setUp(adapter.reset);

      test('initialize delegates to the notifier', () async {
        final service = NotificationService.withNotifier(adapter.notifier);

        await service.initialize();

        expect(adapter.notifier.initializeCount, 1);
      });

      test('requestPermissions returns the notifier result', () async {
        final service = NotificationService.withNotifier(adapter.notifier);

        final granted = await service.requestPermissions();

        expect(granted, isTrue);
        expect(adapter.notifier.requestPermissionsCount, 1);
      });

      test('requestPermissions returns false when notifier denies',
          () async {
        adapter.notifier.permissionsGranted = false;
        final service = NotificationService.withNotifier(adapter.notifier);

        final granted = await service.requestPermissions();

        expect(granted, isFalse);
      });

      test('cancelReminder delegates the id to the notifier', () async {
        final service = NotificationService.withNotifier(adapter.notifier);

        await service.cancelReminder(42);

        expect(adapter.notifier.canceledIds, [42]);
      });

      test('cancelAllReminders delegates to the notifier', () async {
        final service = NotificationService.withNotifier(adapter.notifier);

        await service.cancelAllReminders();

        expect(adapter.notifier.cancelAllCount, 1);
      });

      test('updateMealReminders cancels then schedules three reminders',
          () async {
        final service = NotificationService.withNotifier(adapter.notifier);

        await service.updateMealReminders(
          enabled: true,
          breakfastTime: '08:00',
          lunchTime: '12:30',
          dinnerTime: '19:00',
        );

        expect(adapter.notifier.canceledIds, [0, 1, 2]);
        expect(adapter.notifier.scheduled, hasLength(3));

        final byId = {
          for (final entry in adapter.notifier.scheduled) entry.id: entry,
        };
        expect(byId[0]!.title, 'Time for Breakfast! 🍳');
        expect(byId[1]!.title, 'Time for Lunch! 🥗');
        expect(byId[2]!.title, 'Time for Dinner! 🍽️');
        expect(byId[0]!.body, contains('breakfast'));
        expect(byId[1]!.body, contains('lunch'));
        expect(byId[2]!.body, contains('dinner'));
      });

      test('updateMealReminders with enabled=false schedules nothing',
          () async {
        final service = NotificationService.withNotifier(adapter.notifier);

        await service.updateMealReminders(enabled: false);

        expect(adapter.notifier.scheduled, isEmpty);
        // The implementation cancels existing reminders first, so
        // the three meal ids should still appear in canceledIds.
        expect(adapter.notifier.canceledIds, [0, 1, 2]);
      });

      test('updateMealReminders skips meals with null times', () async {
        final service = NotificationService.withNotifier(adapter.notifier);

        await service.updateMealReminders(
          enabled: true,
          breakfastTime: '08:00',
        );

        expect(adapter.notifier.scheduled, hasLength(1));
        expect(adapter.notifier.scheduled.single.id, 0);
      });

      test('scheduleMealReminder rolls past times to tomorrow', () async {
        final service = NotificationService.withNotifier(adapter.notifier);

        final now = tz.TZDateTime.now(tz.local);
        // Pick an hour that's definitely earlier than `now.hour` so
        // the rollover triggers.
        final earlierHour = (now.hour + 23) % 24;
        const earlierMinute = 0;

        await service.scheduleMealReminder(
          id: 9,
          title: 'x',
          body: 'y',
          hour: earlierHour,
          minute: earlierMinute,
        );

        expect(adapter.notifier.scheduled, hasLength(1));
        final when = adapter.notifier.scheduled.single.when;
        expect(when.hour, earlierHour);
        expect(when.minute, earlierMinute);
        // Must not be in the past relative to now.
        expect(when.isAfter(now.subtract(const Duration(minutes: 1))), isTrue);
      });

      test('startTomorrow: true always schedules for tomorrow', () async {
        final service = NotificationService.withNotifier(adapter.notifier);

        final now = tz.TZDateTime.now(tz.local);
        // 23:00 is a safe pick — it'll be in the future today, but
        // startTomorrow: true still pushes it forward.
        await service.scheduleMealReminder(
          id: 7,
          title: 'x',
          body: 'y',
          hour: 23,
          minute: 0,
          startTomorrow: true,
        );

        final when = adapter.notifier.scheduled.single.when;
        expect(when.day, isNot(equals(now.day)));
      });
    });
  }
}
