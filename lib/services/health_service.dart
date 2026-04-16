import 'package:health/health.dart';

abstract class HealthServiceProtocol {
  Future<void> initialize();
  bool isAvailable();
  Future<bool> requestPermissions();
  Future<bool> hasPermissions();
  Future<bool> requestWeightPermissions();
  Future<bool> requestNutritionPermissions();
  Future<double> getTodayBurnedCalories();
  Future<double> getBurnedCaloriesForDate(DateTime date);
  Future<List<({double kg, DateTime timestamp})>> getWeightEntries(
    DateTime start,
    DateTime end,
  );
  Future<bool> writeWeight(double kg, DateTime timestamp);
  Future<void> writeNutritionForDay(
    DateTime date, {
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  });
}

class HealthService implements HealthServiceProtocol {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health _health = Health();
  bool _initialized = false;

  static const _burnedTypes = [HealthDataType.ACTIVE_ENERGY_BURNED];
  static const _burnedPermissions = [HealthDataAccess.READ];

  static const _weightTypes = [HealthDataType.WEIGHT];
  static const _weightPermissions = [HealthDataAccess.READ_WRITE];

  static const _nutritionTypes = [
    HealthDataType.DIETARY_ENERGY_CONSUMED,
    HealthDataType.DIETARY_PROTEIN_CONSUMED,
    HealthDataType.DIETARY_CARBS_CONSUMED,
    HealthDataType.DIETARY_FATS_CONSUMED,
  ];
  static const _nutritionPermissions = [
    HealthDataAccess.WRITE,
    HealthDataAccess.WRITE,
    HealthDataAccess.WRITE,
    HealthDataAccess.WRITE,
  ];

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await _health.configure();
    _initialized = true;
  }

  @override
  bool isAvailable() => true;

  @override
  Future<bool> requestPermissions() async {
    try {
      await initialize();
      return await _health.requestAuthorization(
        _burnedTypes,
        permissions: _burnedPermissions,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> hasPermissions() async {
    try {
      await initialize();
      return await _health.hasPermissions(
            _burnedTypes,
            permissions: _burnedPermissions,
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestWeightPermissions() async {
    try {
      await initialize();
      return await _health.requestAuthorization(
        _weightTypes,
        permissions: _weightPermissions,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestNutritionPermissions() async {
    try {
      await initialize();
      return await _health.requestAuthorization(
        _nutritionTypes,
        permissions: _nutritionPermissions,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<double> getTodayBurnedCalories() async {
    return getBurnedCaloriesForDate(DateTime.now());
  }

  @override
  Future<double> getBurnedCaloriesForDate(DateTime date) async {
    try {
      await initialize();
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: _burnedTypes,
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

  @override
  Future<List<({double kg, DateTime timestamp})>> getWeightEntries(
    DateTime start,
    DateTime end,
  ) async {
    try {
      await initialize();
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: _weightTypes,
      );
      final deduped = _health.removeDuplicates(data);
      return deduped
          .where((p) => p.value is NumericHealthValue)
          .map(
            (p) => (
              kg: (p.value as NumericHealthValue).numericValue.toDouble(),
              timestamp: p.dateFrom,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<bool> writeWeight(double kg, DateTime timestamp) async {
    try {
      await initialize();
      return await _health.writeHealthData(
        value: kg,
        type: HealthDataType.WEIGHT,
        startTime: timestamp,
        endTime: timestamp,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> writeNutritionForDay(
    DateTime date, {
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    try {
      await initialize();
      final start = DateTime(date.year, date.month, date.day);
      final end = DateTime(date.year, date.month, date.day, 23, 59, 59);

      for (final type in _nutritionTypes) {
        try {
          await _health.delete(type: type, startTime: start, endTime: end);
        } catch (_) {}
      }

      await _health.writeHealthData(
        value: calories,
        type: HealthDataType.DIETARY_ENERGY_CONSUMED,
        startTime: start,
        endTime: end,
      );
      await _health.writeHealthData(
        value: protein,
        type: HealthDataType.DIETARY_PROTEIN_CONSUMED,
        startTime: start,
        endTime: end,
      );
      await _health.writeHealthData(
        value: carbs,
        type: HealthDataType.DIETARY_CARBS_CONSUMED,
        startTime: start,
        endTime: end,
      );
      await _health.writeHealthData(
        value: fat,
        type: HealthDataType.DIETARY_FATS_CONSUMED,
        startTime: start,
        endTime: end,
      );
    } catch (_) {}
  }
}
