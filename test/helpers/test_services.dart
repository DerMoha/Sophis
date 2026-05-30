import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/services/database_service.dart';
import 'package:sophis/services/food_intake_controller.dart';
import 'package:sophis/services/health_service.dart';
import 'package:sophis/services/home_widget_service.dart';
import 'package:sophis/services/notification_service.dart';
import 'package:sophis/services/storage_service.dart';
import 'package:sophis/ui/theme/animations.dart';

class MockNotificationService extends Mock implements NotificationService {}

class FakeHealthService implements HealthServiceProtocol {
  bool permissionsGranted;
  bool weightPermissionsGranted;
  bool nutritionPermissionsGranted;
  double todayBurnedCalories;
  List<({double kg, DateTime timestamp})> weightEntries;
  final List<({double kg, DateTime timestamp})> writtenWeights = [];
  final List<
      ({
        DateTime date,
        double calories,
        double protein,
        double carbs,
        double fat,
        double fiber,
      })> writtenNutrition = [];

  FakeHealthService({
    this.permissionsGranted = true,
    this.weightPermissionsGranted = true,
    this.nutritionPermissionsGranted = true,
    this.todayBurnedCalories = 0,
    this.weightEntries = const [],
  });

  @override
  Future<void> initialize() async {}

  @override
  bool isAvailable() => true;

  @override
  Future<bool> requestPermissions() async => permissionsGranted;

  @override
  Future<bool> hasPermissions() async => permissionsGranted;

  @override
  Future<bool> requestWeightPermissions() async => weightPermissionsGranted;

  @override
  Future<bool> requestNutritionPermissions() async =>
      nutritionPermissionsGranted;

  @override
  Future<double> getTodayBurnedCalories() async => todayBurnedCalories;

  @override
  Future<double> getBurnedCaloriesForDate(DateTime date) async =>
      todayBurnedCalories;

  @override
  Future<List<({double kg, DateTime timestamp})>> getWeightEntries(
    DateTime start,
    DateTime end,
  ) async =>
      weightEntries;

  @override
  Future<bool> writeWeight(double kg, DateTime timestamp) async {
    writtenWeights.add((kg: kg, timestamp: timestamp));
    return true;
  }

  @override
  Future<void> writeNutritionForDay(
    DateTime date, {
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required double fiber,
  }) async {
    writtenNutrition.add(
      (
        date: date,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        fiber: fiber,
      ),
    );
  }
}

MockNotificationService createMockNotificationService() {
  final notifications = MockNotificationService();
  when(
    () => notifications.updateMealReminders(
      enabled: any(named: 'enabled'),
      breakfastTime: any(named: 'breakfastTime'),
      lunchTime: any(named: 'lunchTime'),
      dinnerTime: any(named: 'dinnerTime'),
    ),
  ).thenAnswer((_) async {});
  when(() => notifications.requestPermissions()).thenAnswer((_) async => true);
  when(() => notifications.cancelReminder(any())).thenAnswer((_) async {});
  when(() => notifications.cancelAllReminders()).thenAnswer((_) async {});
  when(
    () => notifications.scheduleMealReminder(
      id: any(named: 'id'),
      title: any(named: 'title'),
      body: any(named: 'body'),
      hour: any(named: 'hour'),
      minute: any(named: 'minute'),
      startTomorrow: any(named: 'startTomorrow'),
    ),
  ).thenAnswer((_) async {});
  return notifications;
}

Future<StorageService> createTestStorage({
  Map<String, Object> initialValues = const <String, Object>{},
  Map<String, String> secureValues = const <String, String>{},
}) async {
  SharedPreferences.setMockInitialValues(
    Map<String, Object>.from(initialValues),
  );
  FlutterSecureStorage.setMockInitialValues(
    Map<String, String>.from(secureValues),
  );
  final prefs = await SharedPreferences.getInstance();
  return StorageService(prefs, const FlutterSecureStorage());
}

DatabaseService createTestDatabase() => DatabaseService.inMemory();

Future<void> waitForNutritionProvider(NutritionProvider provider) async {
  for (var i = 0; i < 50 && provider.isLoading; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  if (provider.isLoading) {
    throw StateError('NutritionProvider did not finish loading');
  }
}

Future<void> waitForNutritionProviderInWidgetTest(
  WidgetTester tester,
  NutritionProvider provider,
) async {
  for (var i = 0; i < 50 && provider.isLoading; i++) {
    await tester.pump();
  }
  if (provider.isLoading) {
    throw StateError('NutritionProvider did not finish loading');
  }
}

Future<NutritionProvider> createLoadedNutritionProvider({
  StorageService? storage,
  DatabaseService? database,
  HealthServiceProtocol? healthService,
}) async {
  HomeWidgetService.setEnabledForTesting(false);
  final shouldCloseDatabase = database == null;
  final db = database ?? createTestDatabase();
  final provider = NutritionProvider(
    storage ?? await createTestStorage(),
    db,
    healthService: healthService ?? FakeHealthService(),
    cleanupProgressPhotosOnLoad: false,
  );
  if (shouldCloseDatabase) {
    addTearDown(db.close);
  }
  await waitForNutritionProvider(provider);
  return provider;
}

Future<NutritionProvider> createLoadedWidgetNutritionProvider(
  WidgetTester tester, {
  StorageService? storage,
  DatabaseService? database,
  HealthServiceProtocol? healthService,
}) async {
  HomeWidgetService.setEnabledForTesting(false);
  final shouldCloseDatabase = database == null;
  final db = database ?? createTestDatabase();
  final provider = NutritionProvider(
    storage ?? await createTestStorage(),
    db,
    healthService: healthService ?? FakeHealthService(),
    cleanupProgressPhotosOnLoad: false,
  );
  if (shouldCloseDatabase) {
    addTearDown(db.close);
  }
  await waitForNutritionProviderInWidgetTest(tester, provider);
  return provider;
}

Future<SettingsProvider> createTestSettingsProvider({
  StorageService? storage,
  MockNotificationService? notifications,
  HealthServiceProtocol? healthService,
}) async {
  final provider = SettingsProvider(
    storage ?? await createTestStorage(),
    notificationService: notifications ?? createMockNotificationService(),
    healthService: healthService ?? FakeHealthService(),
  );
  await Future<void>.delayed(Duration.zero);
  return provider;
}

Future<SettingsProvider> createWidgetTestSettingsProvider(
  WidgetTester tester, {
  StorageService? storage,
  MockNotificationService? notifications,
  HealthServiceProtocol? healthService,
}) async {
  final provider = SettingsProvider(
    storage ?? await createTestStorage(),
    notificationService: notifications ?? createMockNotificationService(),
    healthService: healthService ?? FakeHealthService(),
  );
  await tester.pump();
  return provider;
}

Future<void> pumpTestApp(
  WidgetTester tester,
  Widget child, {
  NutritionProvider? nutritionProvider,
  SettingsProvider? settingsProvider,
  FoodIntakeController? foodIntakeController,
}) async {
  FadeInSlide.setEnabledForTesting(false);
  final providers = <SingleChildWidget>[
    if (settingsProvider != null)
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
    if (nutritionProvider != null)
      ChangeNotifierProvider<NutritionProvider>.value(value: nutritionProvider),
    if (foodIntakeController != null)
      Provider<FoodIntakeController>.value(value: foodIntakeController),
  ];

  final app = MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );

  await tester.pumpWidget(
    providers.isEmpty ? app : MultiProvider(providers: providers, child: app),
  );
}
