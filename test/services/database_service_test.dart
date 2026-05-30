import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/custom_portion.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/meal_plan.dart';
import 'package:sophis/models/progress_photo.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/models/supplement.dart';
import 'package:sophis/models/supplement_log.dart';
import 'package:sophis/models/water_entry.dart';
import 'package:sophis/models/weight_entry.dart';
import 'package:sophis/models/workout_entry.dart';
import 'package:sophis/services/database_service.dart';

import '../helpers/test_services.dart';

void main() {
  group('DatabaseService', () {
    late DatabaseService db;

    setUp(() {
      db = createTestDatabase();
      addTearDown(db.close);
    });

    test('persisted and cleared daily log tables', () async {
      final timestamp = DateTime(2026, 1, 2, 8, 30);
      final food = FoodEntry(
        id: 'food-1',
        name: 'Toast',
        calories: 250,
        protein: 10,
        carbs: 35,
        fat: 7,
        fiber: 4,
        timestamp: timestamp,
        meal: 'breakfast',
      );
      final updatedFood = food.copyWith(calories: 300, meal: 'lunch');
      final water = WaterEntry(
        id: 'water-1',
        amountMl: 500,
        timestamp: timestamp,
      );
      final weight = WeightEntry(
        id: 'weight-1',
        weightKg: 80,
        timestamp: timestamp,
        source: 'health',
      );
      final workout = WorkoutEntry(
        id: 'workout-1',
        caloriesBurned: 350,
        timestamp: timestamp,
        note: 'Run',
      );

      await db.insertFood(food);
      await db.updateFood(updatedFood);
      await db.insertWater(water);
      await db.insertWeight(weight);
      await db.insertWorkout(workout);
      await db.updateWorkout(workout.copyWith(caloriesBurned: 400));

      expect((await db.getAllFoods()).single.calories, 300);
      expect((await db.getAllFoods()).single.meal, 'lunch');
      expect((await db.getAllWater()).single.amountMl, 500);
      expect((await db.getAllWeights()).single.source, 'health');
      expect((await db.getAllWorkouts()).single.caloriesBurned, 400);

      await db.deleteAllData();

      expect(await db.getAllFoods(), isEmpty);
      expect(await db.getAllWater(), isEmpty);
      expect(await db.getAllWeights(), isEmpty);
      expect(await db.getAllWorkouts(), isEmpty);
    });

    test('managed supplements, logs, and barcode cache expiry', () async {
      final now = DateTime.now();
      final supplementA = Supplement(
        id: 'supplement-a',
        name: 'Vitamin D',
        sortOrder: 1,
        createdAt: now,
      );
      final supplementB = Supplement(
        id: 'supplement-b',
        name: 'Magnesium',
        sortOrder: 0,
        createdAt: now,
      );
      final log = SupplementLogEntry(
        id: 'log-1',
        supplementId: supplementA.id,
        timestamp: now,
      );

      await db.insertSupplement(supplementA);
      await db.insertSupplement(supplementB);
      await db.insertSupplementLog(log);

      final supplements = await db.getAllSupplements();
      expect(supplements.map((supplement) => supplement.id), [
        'supplement-b',
        'supplement-a',
      ]);
      expect(await db.getSupplementLogsByDate(now), hasLength(1));

      await db.upsertBarcodeCache(
        BarcodeProductsCompanion(
          barcode: const Value('expired-not-found'),
          name: const Value('Missing'),
          cacheStatus: const Value('notFound'),
          cachedAt: Value(now.subtract(const Duration(days: 8))),
        ),
      );
      await db.upsertBarcodeCache(
        BarcodeProductsCompanion(
          barcode: const Value('fresh-found'),
          name: const Value('Fresh'),
          cacheStatus: const Value('found'),
          cachedAt: Value(now.subtract(const Duration(days: 2))),
        ),
      );
      await db.upsertBarcodeCache(
        BarcodeProductsCompanion(
          barcode: const Value('user-corrected'),
          name: const Value('Corrected'),
          cacheStatus: const Value('found'),
          isUserCorrected: const Value(true),
          cachedAt: Value(now.subtract(const Duration(days: 90))),
        ),
      );

      await db.deleteExpiredBarcodeCache();

      expect(await db.getCachedBarcode('expired-not-found'), isNull);
      expect((await db.getCachedBarcode('fresh-found'))?.name, 'Fresh');
      expect(
        (await db.getCachedBarcode('user-corrected'))?.isUserCorrected,
        isTrue,
      );
    });

    test('migrated secondary models into SQLite tables', () async {
      final timestamp = DateTime(2026, 1, 2, 8, 30);
      final recipe = Recipe(
        id: 'recipe-1',
        name: 'Chili',
        ingredients: const [
          RecipeIngredient(
            id: 'beans',
            name: 'Beans',
            amountGrams: 200,
            calories: 250,
            protein: 15,
            carbs: 40,
            fat: 2,
          ),
        ],
        createdAt: timestamp,
      );
      const food = FoodItem(
        id: 'food-1',
        name: 'Yogurt',
        category: 'dairy',
        caloriesPer100g: 90,
        proteinPer100g: 10,
        carbsPer100g: 4,
        fatPer100g: 2,
        fiberPer100g: 1,
      );
      final plannedMeal = PlannedMeal(
        id: 'planned-1',
        date: timestamp,
        meal: 'dinner',
        name: 'Chili',
        calories: 500,
        protein: 30,
        carbs: 50,
        fat: 12,
        ingredients: const [
          PlannedMealIngredient(
            name: 'Tomato',
            amount: 2,
            unit: 'pcs',
            category: ShoppingCategory.produce,
          ),
        ],
      );
      final portion = CustomPortion(
        id: 'portion-1',
        productKey: 'name:yogurt',
        name: 'Cup',
        grams: 150,
        createdAt: timestamp,
      );
      final photo = ProgressPhoto(
        id: 'photo-1',
        imagePath: '/tmp/photo.jpg',
        timestamp: timestamp,
        weightKg: 80,
        category: PhotoCategory.side,
        createdAt: timestamp,
      );

      await db.migrateRecipe(recipe);
      await db.migrateCustomFood(food);
      await db.migrateFavoriteFoods([food]);
      await db.migratePlannedMeal(plannedMeal);
      await db.migrateCustomPortions([portion]);
      await db.migrateRecentFoods([food]);
      await db.insertPhoto(photo);

      expect((await db.getAllRecipes()).single.name, 'Chili');
      expect((await db.getAllCustomFoods()).single.fiberPer100g, 1);
      expect((await db.getAllFavoriteFoods()).single.id, 'food-1');
      expect((await db.getAllPlannedMeals()).single.fiber, 0);
      expect((await db.getAllCustomPortions()).single.grams, 150);
      expect((await db.getPhotoById('photo-1'))?.category, PhotoCategory.side);
      expect(await db.getPhotosByCategory(PhotoCategory.side), hasLength(1));
    });
  });
}
