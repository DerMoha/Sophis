import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/meal_plan.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/progress_photo.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/models/user_profile.dart';
import 'package:sophis/models/water_entry.dart';
import 'package:sophis/models/weight_entry.dart';
import 'package:sophis/models/workout_entry.dart';

import '../helpers/test_services.dart';

void main() {
  group('NutritionProvider', () {
    test('migrated legacy storage data into the database on load', () async {
      final storage = await createTestStorage();
      final db = createTestDatabase();
      addTearDown(db.close);
      final loggedAt = DateTime.now();

      await storage.saveFoodEntries([
        FoodEntry(
          id: 'food-1',
          name: 'Eggs',
          calories: 150,
          protein: 12,
          carbs: 1,
          fat: 10,
          timestamp: loggedAt,
          meal: 'breakfast',
        ),
      ]);
      await storage.saveWaterEntries([
        WaterEntry(id: 'water-1', amountMl: 300, timestamp: loggedAt),
      ]);
      await storage.saveWeightEntries([
        WeightEntry(id: 'weight-1', weightKg: 72, timestamp: loggedAt),
      ]);
      await storage.saveWorkoutEntries([
        WorkoutEntry(
          id: 'workout-1',
          caloriesBurned: 80,
          timestamp: loggedAt,
        ),
      ]);

      final provider = await createLoadedNutritionProvider(
        storage: storage,
        database: db,
      );

      expect(provider.entries.single.id, 'food-1');
      expect(provider.waterEntries.single.id, 'water-1');
      expect(provider.weightEntries.single.id, 'weight-1');
      expect(provider.workoutEntries.single.id, 'workout-1');
      expect(await db.getAllFoods(), hasLength(1));
      expect(await db.getAllWater(), hasLength(1));
      expect(storage.loadFoodEntries(), isEmpty);
      expect(storage.loadWaterEntries(), isEmpty);
      expect(storage.isMigrationComplete(), isTrue);
    });

    test('tracked goals, entries, totals, and health sync writes', () async {
      final storage = await createTestStorage();
      final db = createTestDatabase();
      addTearDown(db.close);
      final health = FakeHealthService(
        todayBurnedCalories: 120,
        weightEntries: [
          (
            kg: 70.5,
            timestamp: DateTime.now().subtract(const Duration(days: 1))
          ),
        ],
      );
      final provider = await createLoadedNutritionProvider(
        storage: storage,
        database: db,
        healthService: health,
      );
      final settings = await createTestSettingsProvider(
        storage: storage,
        healthService: health,
      );
      await settings.setHealthWeightSyncEnabled(true);
      await settings.setHealthNutritionSyncEnabled(true);
      provider.attachSettingsProvider(settings);

      await provider.setGoals(NutritionGoals(calories: 2000));
      await provider.setProfile(
        const UserProfile(
          weight: 70,
          height: 175,
          age: 35,
          gender: Gender.male,
          activityLevel: ActivityLevel.moderate,
          goal: Goal.maintain,
        ),
      );
      final entry = FoodEntry(
        id: 'entry-1',
        name: 'Rice bowl',
        calories: 500,
        protein: 20,
        carbs: 70,
        fat: 12,
        fiber: 8,
        timestamp: DateTime.now(),
        meal: 'lunch',
      );

      await provider.addFoodEntry(entry);
      await provider.addWater(250);
      await provider.addWorkoutEntry(60, note: 'Walk');
      await provider.addWeight(70, note: 'Morning');
      await provider.refreshBurnedCalories();
      await provider.syncWeightFromHealth();

      expect(provider.goals?.calories, 2000);
      expect(provider.profile?.age, 35);
      expect(provider.getTodayTotals().calories, 500);
      expect(provider.getRemainingCalories(), 1680);
      expect(provider.getTodayWaterTotal(), 250);
      expect(provider.getTodayWorkoutCalories(), 60);
      expect(provider.burnedCalories, 180);
      expect(health.writtenNutrition.single.calories, 500);
      expect(health.writtenWeights.single.kg, 70);
      expect(provider.weightEntries, hasLength(2));
      expect(provider.latestWeight?.weightKg, 70);
    });

    test('managed libraries, planning, photos, and clear-all state', () async {
      final storage = await createTestStorage();
      final db = createTestDatabase();
      addTearDown(db.close);
      final provider = await createLoadedNutritionProvider(
        storage: storage,
        database: db,
      );
      final today = DateTime.now();
      final recipe = Recipe(
        id: 'recipe-1',
        name: 'Oats',
        ingredients: const [
          RecipeIngredient(
            id: 'oats',
            name: 'Oats',
            amountGrams: 50,
            calories: 180,
            protein: 6,
            carbs: 30,
            fat: 4,
          ),
        ],
        createdAt: today,
      );
      const customFood = FoodItem(
        id: 'custom-1',
        name: 'Shake',
        category: 'custom',
        caloriesPer100g: 100,
        proteinPer100g: 20,
        carbsPer100g: 5,
        fatPer100g: 2,
      );
      final plannedMeal = PlannedMeal(
        id: 'planned-1',
        date: today,
        meal: 'breakfast',
        name: 'Oats',
        calories: 180,
        protein: 6,
        carbs: 30,
        fat: 4,
        ingredients: const [
          PlannedMealIngredient(
            name: 'Oats',
            amount: 50,
            unit: 'g',
            category: ShoppingCategory.grains,
          ),
        ],
      );
      final photo = ProgressPhoto(
        id: 'photo-1',
        imagePath: '/tmp/photo.jpg',
        timestamp: today,
        createdAt: today,
      );

      await provider.addRecipe(recipe);
      await provider.addCustomFood(customFood);
      await provider.toggleFavorite(customFood);
      await provider.addPlannedMeal(plannedMeal);
      await provider.toggleShoppingItem('Oats', 'g');
      await provider.restoreProgressPhoto(photo);

      expect(provider.recipes.single.id, 'recipe-1');
      expect(provider.searchCustomFoods('sha').single.id, 'custom-1');
      expect(provider.isFavorite('custom-1'), isTrue);
      expect(provider.getPlannedTotalsForDate(today).calories, 180);
      expect(
        provider.generateShoppingList(today, today).single.isChecked,
        isTrue,
      );
      expect(provider.photos.single.id, 'photo-1');

      await provider.clearAllData();

      expect(provider.goals, isNull);
      expect(provider.entries, isEmpty);
      expect(provider.waterEntries, isEmpty);
      expect(provider.recipes, isEmpty);
      expect(provider.customFoods, isEmpty);
      expect(provider.favoriteFoods, isEmpty);
      expect(provider.plannedMeals, isEmpty);
      expect(provider.photos, isEmpty);
      expect(await db.getAllFoods(), isEmpty);
      expect(storage.loadGoals(), isNull);
    });
  });
}
