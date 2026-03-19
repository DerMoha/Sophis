import 'package:health/health.dart';

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health _health = Health();
  bool _initialized = false;

  static const _types = [HealthDataType.ACTIVE_ENERGY_BURNED];
  static const _permissions = [HealthDataAccess.READ];

  Future<void> initialize() async {
    if (_initialized) return;
    await _health.configure();
    _initialized = true;
  }

  bool isAvailable() => true;

  Future<bool> requestPermissions() async {
    try {
      await initialize();
      return await _health.requestAuthorization(_types, permissions: _permissions);
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasPermissions() async {
    try {
      await initialize();
      return await _health.hasPermissions(_types, permissions: _permissions) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<double> getTodayBurnedCalories() async {
    return getBurnedCaloriesForDate(DateTime.now());
  }

  Future<double> getBurnedCaloriesForDate(DateTime date) async {
    try {
      await initialize();
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: _types,
      );
      final deduped = _health.removeDuplicates(data);
      return deduped.fold<double>(0.0, (sum, point) {
        final value = point.value;
        if (value is NumericHealthValue) {
          return sum + value.numericValue.toDouble();
        }
        return sum;
      });
    } catch (_) {
      return 0.0;
    }
  }
}
