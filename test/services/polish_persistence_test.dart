import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/services/food_intake_controller.dart';
import 'package:sophis/services/service_result.dart';

import '../helpers/test_services.dart';

class _FailingHealth extends FakeHealthService {
  @override
  Future<bool> writeWeight(double kg, DateTime timestamp) async =>
      throw StateError('Health unavailable');

  @override
  Future<void> writeNutritionForDay(
    DateTime date, {
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required double fiber,
  }) async =>
      throw StateError('Health unavailable');
}

void main() {
  test('kept durable local writes successful when optional Health sync failed',
      () async {
    final health = _FailingHealth();
    final settings = await createTestSettingsProvider(healthService: health);
    await settings.setHealthNutritionSyncEnabled(true);
    await settings.setHealthWeightSyncEnabled(true);
    final provider = await createLoadedNutritionProvider(healthService: health);
    provider.attachSettingsProvider(settings);
    final entry = FoodEntry(
        id: 'local',
        name: 'Toast',
        calories: 100,
        protein: 3,
        carbs: 18,
        fat: 1,
        meal: 'breakfast',
        timestamp: DateTime.now(),);
    await provider.addFoodEntry(entry);
    await provider.addWeight(72.5);
    expect(provider.entries.single.id, 'local');
    expect(provider.weightEntries.single.weightKg, 72.5);
    await provider.reloadAll();
    expect(provider.entries.single.id, 'local');
    expect(provider.weightEntries.single.weightKg, 72.5);
  });

  test('rolled back diary and library together and saved exactly once on retry',
      () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final provider = await createLoadedNutritionProvider(database: database);
    final controller = FoodIntakeController(provider);
    await database.customStatement('''
      CREATE TRIGGER fail_library BEFORE INSERT ON custom_foods
      BEGIN SELECT RAISE(ABORT, 'simulated library failure'); END
    ''');
    Future<ServiceResult<FoodEntry>> save() => controller.logManualEntry(
        name: 'Toast',
        calories: 100,
        protein: 3,
        carbs: 18,
        fat: 1,
        meal: 'breakfast',
        saveAsCustomFood: true,);
    expect((await save()).isFailure, isTrue);
    expect(provider.entries, isEmpty);
    expect(provider.customFoods, isEmpty);
    expect(await database.getAllFoods(), isEmpty);
    await database.customStatement('DROP TRIGGER fail_library');
    expect((await save()).isSuccess, isTrue);
    expect(provider.entries, hasLength(1));
    expect(provider.customFoods, hasLength(1));
    await provider.reloadAll();
    expect(provider.entries, hasLength(1));
    expect(provider.customFoods, hasLength(1));
  });
}
