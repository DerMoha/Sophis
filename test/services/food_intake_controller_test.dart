import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/shareable_meal.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/services/food_intake_controller.dart';
import 'package:sophis/services/service_result.dart';

class MockNutritionProvider extends Mock implements NutritionProvider {}

class FakeFoodEntry extends Fake implements FoodEntry {}

class FakeFoodItem extends Fake implements FoodItem {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeFoodEntry());
    registerFallbackValue(FakeFoodItem());
  });

  group('FoodIntakeController', () {
    late MockNutritionProvider nutrition;
    late DateTime timestamp;
    late List<String> ids;
    late FoodIntakeController controller;

    String nextId() => ids.removeAt(0);

    void stubSuccessfulWrites() {
      when(() => nutrition.addFoodEntry(any())).thenAnswer((_) async {});
      when(
        () => nutrition.addRecentFood(any(), meal: any(named: 'meal')),
      ).thenAnswer((_) async {});
      when(() => nutrition.addCustomFood(any())).thenAnswer((_) async {});
    }

    setUp(() {
      nutrition = MockNutritionProvider();
      timestamp = DateTime(2026, 1, 2, 8, 30);
      ids = ['entry-1', 'entry-2', 'custom-1', 'entry-3', 'entry-4'];
      controller = FoodIntakeController(
        nutrition,
        now: () => timestamp,
        idGenerator: nextId,
      );
      stubSuccessfulWrites();
    });

    test('logs a food item and records it as recent food', () async {
      const item = FoodItem(
        id: 'apple',
        name: 'Apple',
        category: 'fruit',
        caloriesPer100g: 52,
        proteinPer100g: 0.3,
        carbsPer100g: 14,
        fatPer100g: 0.2,
        brand: 'Farm Fresh',
      );

      final result = await controller.logFoodItem(
        item: item,
        grams: 150,
        meal: 'snack',
      );

      expect(result, isA<Success<FoodEntry>>());
      final entry = result.value;
      expect(entry.id, 'entry-1');
      expect(entry.name, 'Farm Fresh Apple (150g)');
      expect(entry.calories, 78);
      expect(entry.protein, closeTo(0.45, 0.0001));
      expect(entry.carbs, 21);
      expect(entry.fat, closeTo(0.3, 0.0001));
      expect(entry.meal, 'snack');
      expect(entry.timestamp, timestamp);

      verify(() => nutrition.addFoodEntry(entry)).called(1);
      verify(() => nutrition.addRecentFood(item, meal: 'snack')).called(1);
    });

    test('logs a manual entry and saves it as a custom food', () async {
      final result = await controller.logManualEntry(
        name: 'Protein Shake',
        calories: 220,
        protein: 30,
        carbs: 12,
        fat: 5,
        fiber: 1,
        meal: 'breakfast',
        saveAsCustomFood: true,
      );

      expect(result, isA<Success<FoodEntry>>());
      final entry = result.value;
      expect(entry.id, 'entry-1');
      expect(entry.name, 'Protein Shake');
      expect(entry.calories, 220);
      expect(entry.protein, 30);
      expect(entry.carbs, 12);
      expect(entry.fat, 5);
      expect(entry.fiber, 1);
      expect(entry.meal, 'breakfast');
      expect(entry.timestamp, timestamp);

      final customFood = verify(
        () => nutrition.addCustomFood(captureAny()),
      ).captured.single as FoodItem;
      expect(customFood.id, 'custom_entry-2');
      expect(customFood.name, 'Protein Shake');
      expect(customFood.category, 'custom');
      expect(customFood.caloriesPer100g, 220);
      expect(customFood.proteinPer100g, 30);
      expect(customFood.carbsPer100g, 12);
      expect(customFood.fatPer100g, 5);
      expect(customFood.fiberPer100g, 1);
    });

    test('logs an already-scaled nutrition entry without recent food',
        () async {
      final result = await controller.logNutritionEntry(
        name: 'Soup (1 bowl)',
        calories: 180,
        protein: 8,
        carbs: 24,
        fat: 6,
        fiber: 4,
        meal: 'lunch',
      );

      expect(result, isA<Success<FoodEntry>>());
      final entry = result.value;
      expect(entry.id, 'entry-1');
      expect(entry.name, 'Soup (1 bowl)');
      expect(entry.calories, 180);
      expect(entry.protein, 8);
      expect(entry.carbs, 24);
      expect(entry.fat, 6);
      expect(entry.fiber, 4);
      expect(entry.meal, 'lunch');

      verify(() => nutrition.addFoodEntry(entry)).called(1);
      verifyNever(
        () => nutrition.addRecentFood(any(), meal: any(named: 'meal')),
      );
      verifyNever(() => nutrition.addCustomFood(any()));
    });

    test('imports a shared meal with deterministic entries', () async {
      const meal = ShareableMeal(
        title: 'Dinner',
        items: [
          SharedFoodItem(
            name: 'Rice',
            calories: 200,
            protein: 4,
            carbs: 44,
            fat: 1,
            fiber: 2,
          ),
          SharedFoodItem(
            name: 'Chicken',
            calories: 260,
            protein: 38,
            carbs: 0,
            fat: 10,
            fiber: 0,
          ),
        ],
      );

      final result = await controller.importSharedMeal(
        meal: meal,
        targetMeal: 'dinner',
      );

      expect(result, isA<Success<List<FoodEntry>>>());
      final entries = result.value;
      expect(entries, hasLength(2));
      expect(entries[0].id, 'entry-1');
      expect(entries[0].name, 'Rice');
      expect(entries[0].timestamp, timestamp);
      expect(entries[0].meal, 'dinner');
      expect(entries[1].id, 'entry-2');
      expect(entries[1].name, 'Chicken');
      expect(entries[1].timestamp, timestamp);
      expect(entries[1].meal, 'dinner');

      verify(() => nutrition.addFoodEntry(entries[0])).called(1);
      verify(() => nutrition.addFoodEntry(entries[1])).called(1);
      verifyNever(
        () => nutrition.addRecentFood(any(), meal: any(named: 'meal')),
      );
    });

    test('saves an existing entry as a custom food', () async {
      final entry = FoodEntry(
        id: 'existing-entry',
        name: 'Saved Bowl',
        calories: 420,
        protein: 22,
        carbs: 45,
        fat: 14,
        fiber: 7,
        timestamp: timestamp,
        meal: 'lunch',
      );

      final result = await controller.saveEntryAsCustomFood(entry);

      expect(result, isA<Success<FoodEntry>>());
      expect(result.value, entry);
      final customFood = verify(
        () => nutrition.addCustomFood(captureAny()),
      ).captured.single as FoodItem;
      expect(customFood.id, 'custom_entry-1');
      expect(customFood.name, 'Saved Bowl');
      expect(customFood.caloriesPer100g, 420);
      expect(customFood.proteinPer100g, 22);
      expect(customFood.carbsPer100g, 45);
      expect(customFood.fatPer100g, 14);
      expect(customFood.fiberPer100g, 7);
    });

    test('rejects invalid intake requests before writing', () async {
      final emptyName = await controller.logNutritionEntry(
        name: ' ',
        calories: 10,
        protein: 0,
        carbs: 0,
        fat: 0,
        meal: 'snack',
      );
      final invalidGrams = await controller.logFoodItem(
        item: const FoodItem(
          id: 'apple',
          name: 'Apple',
          category: 'fruit',
          caloriesPer100g: 52,
          proteinPer100g: 0,
          carbsPer100g: 0,
          fatPer100g: 0,
        ),
        grams: 0,
        meal: 'snack',
      );
      final negativeNutrition = await controller.logManualEntry(
        name: 'Bad Food',
        calories: -1,
        protein: 0,
        carbs: 0,
        fat: 0,
        meal: 'snack',
      );

      expect(emptyName, isA<Failure<FoodEntry>>());
      expect(invalidGrams, isA<Failure<FoodEntry>>());
      expect(negativeNutrition, isA<Failure<FoodEntry>>());
      expect(
        (emptyName as Failure<FoodEntry>).errorType,
        ServiceErrorType.parseError,
      );
      verifyNever(() => nutrition.addFoodEntry(any()));
      verifyNever(
        () => nutrition.addRecentFood(any(), meal: any(named: 'meal')),
      );
      verifyNever(() => nutrition.addCustomFood(any()));
    });

    test('returns failure when a provider write throws', () async {
      const item = FoodItem(
        id: 'apple',
        name: 'Apple',
        category: 'fruit',
        caloriesPer100g: 52,
        proteinPer100g: 0,
        carbsPer100g: 0,
        fatPer100g: 0,
      );
      when(
        () => nutrition.addRecentFood(any(), meal: any(named: 'meal')),
      ).thenThrow(Exception('recent failed'));

      final result = await controller.logFoodItem(
        item: item,
        grams: 100,
        meal: 'snack',
      );

      expect(result, isA<Failure<FoodEntry>>());
      final failure = result as Failure<FoodEntry>;
      expect(failure.errorType, ServiceErrorType.unknown);
      expect(failure.message, contains('recent failed'));
      verify(() => nutrition.addFoodEntry(any())).called(1);
      verify(() => nutrition.addRecentFood(item, meal: 'snack')).called(1);
    });

    test('returns failure when saving manual custom food throws', () async {
      when(() => nutrition.addCustomFood(any()))
          .thenThrow(Exception('custom failed'));

      final result = await controller.logManualEntry(
        name: 'Protein Shake',
        calories: 220,
        protein: 30,
        carbs: 12,
        fat: 5,
        meal: 'breakfast',
        saveAsCustomFood: true,
      );

      expect(result, isA<Failure<FoodEntry>>());
      final failure = result as Failure<FoodEntry>;
      expect(failure.errorType, ServiceErrorType.unknown);
      expect(failure.message, contains('custom failed'));
      verify(() => nutrition.addFoodEntry(any())).called(1);
      verify(() => nutrition.addCustomFood(any())).called(1);
    });
  });
}
