import 'dart:io';
import 'package:health/health.dart';

/// Service for reading health data from Apple HealthKit / Google Health Connect
class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health _health = Health();
  bool _isInitialized = false;

  /// The types of health data we want to read
  static final List<HealthDataType> _types = [
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  /// Initialize the health service
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _health.configure();
    _isInitialized = true;
  }

  /// Check if health data is available on this platform
  bool isAvailable() {
    return Platform.isIOS || Platform.isAndroid;
  }

  /// Request permission to read active energy burned
  Future<bool> requestPermissions() async {
    if (!isAvailable()) return false;
    
    await initialize();
    
    try {
      // Request read permissions for active energy burned
      final granted = await _health.requestAuthorization(
        _types,
        permissions: [HealthDataAccess.READ],
      );
      return granted;
    } catch (e) {
      return false;
    }
  }

  /// Check if permissions are granted
  Future<bool> hasPermissions() async {
    if (!isAvailable()) return false;
    
    await initialize();
    
    try {
      final status = await _health.hasPermissions(
        _types,
        permissions: [HealthDataAccess.READ],
      );
      return status ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get today's burned calories (active energy)
  Future<double> getTodayBurnedCalories() async {
    if (!isAvailable()) return 0.0;
    
    await initialize();

    try {
      // Check permissions first
      final hasPerms = await hasPermissions();
      if (!hasPerms) return 0.0;

      // Get today's date range
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Fetch active energy burned data for today
      final healthData = await _health.getHealthDataFromTypes(
        types: _types,
        startTime: startOfDay,
        endTime: now,
      );

      // Sum up all active energy burned values
      double totalCalories = 0.0;
      for (final dataPoint in healthData) {
        if (dataPoint.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
          // Value is in kilocalories
          final value = dataPoint.value;
          if (value is NumericHealthValue) {
            totalCalories += value.numericValue.toDouble();
          }
        }
      }

      return totalCalories;
    } catch (e) {
      return 0.0;
    }
  }

  /// Get burned calories for a specific date
  Future<double> getBurnedCaloriesForDate(DateTime date) async {
    if (!isAvailable()) return 0.0;
    
    await initialize();

    try {
      final hasPerms = await hasPermissions();
      if (!hasPerms) return 0.0;

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final healthData = await _health.getHealthDataFromTypes(
        types: _types,
        startTime: startOfDay,
        endTime: endOfDay,
      );

      double totalCalories = 0.0;
      for (final dataPoint in healthData) {
        if (dataPoint.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
          final value = dataPoint.value;
          if (value is NumericHealthValue) {
            totalCalories += value.numericValue.toDouble();
          }
        }
      }

      return totalCalories;
    } catch (e) {
      return 0.0;
    }
  }
}
