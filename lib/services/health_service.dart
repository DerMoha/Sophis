// ============================================================================
// HEALTH INTEGRATION - CURRENTLY DISABLED
// ============================================================================
// iOS: Crashes without HealthKit entitlements (requires paid Apple Developer account)
// Android: Would work with Health Connect, but disabled for cross-platform consistency
//
// To re-enable Android Health Connect only:
// 1. Uncomment health dependency in pubspec.yaml
// 2. Use conditional imports to only import health on Android
// 3. See health_service_real.dart.disabled for the full implementation
// ============================================================================

/// Stub service for health data - returns disabled/zero values
class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  /// Initialize the health service (no-op when disabled)
  Future<void> initialize() async {}

  /// Health data is not available when disabled
  bool isAvailable() => false;

  /// Request permission - always returns false when disabled
  Future<bool> requestPermissions() async => false;

  /// Check if permissions are granted - always false when disabled
  Future<bool> hasPermissions() async => false;

  /// Get today's burned calories - returns 0 when disabled
  Future<double> getTodayBurnedCalories() async => 0.0;

  /// Get burned calories for a specific date - returns 0 when disabled
  Future<double> getBurnedCaloriesForDate(DateTime date) async => 0.0;
}
