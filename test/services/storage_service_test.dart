import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/app_settings.dart';
import 'package:sophis/models/custom_portion.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/meal_plan.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/models/user_profile.dart';
import 'package:sophis/models/user_stats.dart';
import 'package:sophis/models/water_entry.dart';
import 'package:sophis/models/weight_entry.dart';
import 'package:sophis/models/workout_entry.dart';

import '../helpers/test_services.dart';

void main() {
  group('StorageService', () {
    test('persisted goals, profile, settings, and entry lists', () async {
      final storage = await createTestStorage();
      final timestamp = DateTime(2026, 1, 2, 8, 30);
      final goals = NutritionGoals(calories: 2100, protein: 140);
      const profile = UserProfile(
        weight: 80,
        height: 180,
        age: 30,
        gender: Gender.male,
      );
      const settings = AppSettings(
        themeMode: ThemeMode.dark,
        unitSystem: UnitSystem.imperial,
        waterGoalMl: 2500,
      );
      final foodEntry = FoodEntry(
        id: 'food-1',
        name: 'Oats',
        calories: 300,
        protein: 12,
        carbs: 45,
        fat: 8,
        fiber: 6,
        timestamp: timestamp,
        meal: 'breakfast',
      );
      final waterEntry = WaterEntry(
        id: 'water-1',
        amountMl: 500,
        timestamp: timestamp,
      );
      final weightEntry = WeightEntry(
        id: 'weight-1',
        weightKg: 80,
        timestamp: timestamp,
      );
      final workoutEntry = WorkoutEntry(
        id: 'workout-1',
        caloriesBurned: 350,
        timestamp: timestamp,
      );
      final recipe = Recipe(
        id: 'recipe-1',
        name: 'Chili',
        ingredients: const [],
        createdAt: timestamp,
      );
      final plannedMeal = PlannedMeal(
        id: 'planned-1',
        date: timestamp,
        meal: 'dinner',
        name: 'Chili',
        calories: 500,
        protein: 25,
        carbs: 55,
        fat: 15,
      );
      final portion = CustomPortion(
        id: 'portion-1',
        productKey: 'name:oats',
        name: 'Big bowl',
        grams: 75,
        createdAt: timestamp,
      );
      const customFood = FoodItem(
        id: 'food-item-1',
        name: 'Greek Yogurt',
        category: 'dairy',
        caloriesPer100g: 90,
        proteinPer100g: 10,
        carbsPer100g: 4,
        fatPer100g: 2,
      );
      final stats = UserStats(
        currentStreak: 2,
        longestStreak: 3,
        lastLogDate: timestamp,
        achievements: const [Achievements.firstLog],
        totalDaysLogged: 4,
      );

      await storage.saveGoals(goals);
      await storage.saveProfile(profile);
      await storage.saveSettings(settings);
      await storage.saveFoodEntries([foodEntry]);
      await storage.saveWaterEntries([waterEntry]);
      await storage.saveWeightEntries([weightEntry]);
      await storage.saveWorkoutEntries([workoutEntry]);
      await storage.saveRecipes([recipe]);
      await storage.savePlannedMeals([plannedMeal]);
      await storage.saveShoppingListChecked({'tomato_pcs'});
      await storage.saveCustomPortions([portion]);
      await storage.saveCustomFoods([customFood]);
      await storage.saveFavoriteFoods([customFood.copyWith(isFavorite: true)]);
      await storage.saveUserStats(stats);

      expect(storage.loadGoals()?.calories, 2100);
      expect(storage.loadProfile()?.gender, Gender.male);
      expect(storage.loadSettings().themeMode, ThemeMode.dark);
      expect(storage.loadFoodEntries().single.name, 'Oats');
      expect(storage.loadWaterEntries().single.amountMl, 500);
      expect(storage.loadWeightEntries().single.weightKg, 80);
      expect(storage.loadWorkoutEntries().single.caloriesBurned, 350);
      expect(storage.loadRecipes().single.name, 'Chili');
      expect(storage.loadPlannedMeals().single.name, 'Chili');
      expect(storage.loadShoppingListChecked(), contains('tomato_pcs'));
      expect(storage.loadCustomPortions().single.grams, 75);
      expect(storage.loadCustomFoods().single.name, 'Greek Yogurt');
      expect(storage.loadFavoriteFoods().single.isFavorite, isTrue);
      expect(storage.loadUserStats().achievements, [Achievements.firstLog]);
    });

    test('capped recent foods and preserved meal metadata', () async {
      final storage = await createTestStorage();
      final foods = List<FoodItem>.generate(
        25,
        (index) => FoodItem(
          id: 'food-$index',
          name: 'Food $index',
          category: 'test',
          caloriesPer100g: 100,
          proteinPer100g: 10,
          carbsPer100g: 10,
          fatPer100g: 1,
        ),
      );
      final meals = <String, String>{
        for (final food in foods) food.id: 'breakfast',
      };
      final restoredMeals = <String, String>{};

      await storage.saveRecentFoods(foods, meals);
      final restored = storage.loadRecentFoods(outMeals: restoredMeals);

      expect(restored, hasLength(20));
      expect(restored.first.id, 'food-0');
      expect(restoredMeals['food-0'], 'breakfast');
      expect(restoredMeals.containsKey('food-24'), isFalse);
    });

    test('stored secure values and removed legacy keys after migration',
        () async {
      final storage = await createTestStorage();
      final timestamp = DateTime(2026, 1, 2);
      final entry = FoodEntry(
        id: 'legacy-food',
        name: 'Legacy Food',
        calories: 100,
        protein: 10,
        carbs: 10,
        fat: 2,
        timestamp: timestamp,
        meal: 'snack',
      );
      final recipe = Recipe(
        id: 'legacy-recipe',
        name: 'Legacy Recipe',
        ingredients: const [],
        createdAt: timestamp,
      );

      await storage.saveApiKey('api-key');
      await storage.saveOffCredentials('off-user', 'off-pass');
      expect(await storage.loadApiKey(), 'api-key');
      expect(await storage.loadOffUserId(), 'off-user');
      expect(await storage.loadOffPassword(), 'off-pass');

      await storage.saveApiKey('');
      await storage.saveOffCredentials(null, null);
      expect(await storage.loadApiKey(), isNull);
      expect(await storage.loadOffUserId(), isNull);
      expect(await storage.loadOffPassword(), isNull);

      await storage.saveFoodEntries([entry]);
      await storage.saveRecipes([recipe]);
      await storage.clearLegacyMigratedData();
      await storage.clearLegacyMigratedV2Data();
      expect(storage.loadFoodEntries(), isNotEmpty);
      expect(storage.loadRecipes(), isNotEmpty);

      await storage.setMigrationComplete();
      await storage.setMigrationV2Complete();
      await storage.clearLegacyMigratedData();
      await storage.clearLegacyMigratedV2Data();

      expect(storage.loadFoodEntries(), isEmpty);
      expect(storage.loadRecipes(), isEmpty);
    });
  });
}
