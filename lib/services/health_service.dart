// ============================================================================
// HEALTH INTEGRATION - CURRENTLY DISABLED
// ============================================================================
// To re-enable health integration:
// 1. Uncomment the health dependency in pubspec.yaml
// 2. Replace this file with health_service_real.dart content
// 3. Add HealthKit entitlement for iOS (requires paid Apple Developer account)
// 4. Run flutter pub get
// ============================================================================

/// Stub service for health data - returns disabled/zero values
/// See health_service_real.dart for the actual implementation
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
