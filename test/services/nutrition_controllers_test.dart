import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/custom_portion.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/meal_plan.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/models/water_entry.dart';
import 'package:sophis/models/workout_entry.dart';
import 'package:sophis/services/nutrition/food_library_controller.dart';
import 'package:sophis/services/nutrition/food_log_controller.dart';
import 'package:sophis/services/nutrition/hydration_controller.dart';
import 'package:sophis/services/nutrition/meal_plan_controller.dart';
import 'package:sophis/services/nutrition/workout_controller.dart';

import '../helpers/test_services.dart';

void main() {
  int dayKey(DateTime date) => date.year * 10000 + date.month * 100 + date.day;

  group('Nutrition controllers', () {
    test('managed food entries, totals, meals, and recent foods', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      var changes = 0;
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final controller = FoodLogController(
        db,
        () => changes += 1,
        () => false,
        () => now,
      );
      final breakfast = FoodEntry(
        id: 'breakfast',
        name: 'Oats',
        calories: 300,
        protein: 12,
        carbs: 45,
        fat: 8,
        fiber: 6,
        timestamp: now,
        meal: 'breakfast',
      );
      final lunch = FoodEntry(
        id: 'lunch',
        name: 'Salad',
        calories: 200,
        protein: 8,
        carbs: 20,
        fat: 9,
        timestamp: now,
        meal: 'lunch',
      );
      final oldEntry = FoodEntry(
        id: 'old',
        name: 'Soup',
        calories: 150,
        protein: 6,
        carbs: 18,
        fat: 5,
        timestamp: yesterday,
        meal: 'dinner',
      );

      await db.insertFoods([breakfast, lunch, oldEntry]);
      controller.loadData([breakfast, lunch, oldEntry], <FoodItem>[], const {});

      expect(controller.getTodayEntries(), hasLength(2));
      expect(controller.getEntriesByMeal('breakfast').single.name, 'Oats');
      expect(controller.getTodayTotals().calories, 500);
      expect(controller.getTotalsForDate(yesterday).calories, 150);

      await controller.updateFoodEntry(breakfast.copyWith(calories: 350));
      final updatedFoods = await db.getAllFoods();
      expect(
        updatedFoods.firstWhere((entry) => entry.id == 'breakfast').calories,
        350,
      );

      await controller.removeFoodEntry('breakfast');
      final storedFoods = await db.getAllFoods();
      expect(storedFoods.where((entry) => entry.id == 'breakfast'), isEmpty);
      expect(storedFoods, hasLength(2));
      expect(changes, 2);

      for (var i = 0; i < 25; i++) {
        await controller.addRecentFood(
          FoodItem(
            id: 'recent-$i',
            name: 'Recent $i',
            category: 'test',
            caloriesPer100g: 100,
            proteinPer100g: 10,
            carbsPer100g: 10,
            fatPer100g: 2,
          ),
          meal: i == 24 ? 'snack' : 'dinner',
        );
      }

      expect(controller.recentFoods, hasLength(20));
      expect(controller.getRecentFoodsForMeal('snack').single.id, 'recent-24');
      expect(controller.getRecentFoodsForMeal('breakfast'), hasLength(20));
    });

    test('managed hydration and workout totals for today', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      var changes = 0;
      final now = DateTime.now();
      final older = now.subtract(const Duration(hours: 1));
      final hydration = HydrationController(
        db,
        () => changes += 1,
        () => false,
        () => now,
      );
      final workouts = WorkoutController(
        db,
        () => changes += 1,
        () => false,
        () => now,
      );
      final waterA = WaterEntry(id: 'water-a', amountMl: 250, timestamp: older);
      final waterB = WaterEntry(id: 'water-b', amountMl: 500, timestamp: now);
      final workout = WorkoutEntry(
        id: 'workout-1',
        caloriesBurned: 300,
        timestamp: now,
      );

      await hydration.restoreWaterEntry(waterA);
      await hydration.restoreWaterEntry(waterB);
      await workouts.restoreWorkoutEntry(workout);
      await workouts.updateWorkoutEntry(workout.copyWith(caloriesBurned: 350));

      expect(hydration.getTodayWaterTotal(), 750);
      expect(hydration.getTodayWaterEntries().first.id, 'water-b');
      expect(workouts.getTodayWorkoutCalories(), 350);
      expect(workouts.getTodayWorkoutEntries().single.id, 'workout-1');

      await hydration.removeWaterEntry('water-a');
      await workouts.removeWorkoutEntry('workout-1');

      expect(hydration.getTodayWaterTotal(), 500);
      expect(workouts.getTodayWorkoutCalories(), 0);
      expect(changes, 6);
    });

    test('planned meals aggregated totals and shopping list state', () async {
      final storage = await createTestStorage();
      var changes = 0;
      final controller =
          MealPlanController(storage, () => changes += 1, dayKey);
      final date = DateTime(2026, 1, 2, 19, 30);
      final mealA = PlannedMeal(
        id: 'meal-a',
        date: date,
        meal: 'dinner',
        name: 'Pasta',
        calories: 600,
        protein: 25,
        carbs: 80,
        fat: 15,
        fiber: 8,
        ingredients: const [
          PlannedMealIngredient(
            name: 'Tomato',
            amount: 2,
            unit: 'pcs',
            category: ShoppingCategory.produce,
          ),
        ],
      );
      final mealB = PlannedMeal(
        id: 'meal-b',
        date: date,
        meal: 'lunch',
        name: 'Salad',
        calories: 300,
        protein: 10,
        carbs: 30,
        fat: 12,
        ingredients: const [
          PlannedMealIngredient(
            name: 'tomato',
            amount: 1,
            unit: 'pcs',
            category: ShoppingCategory.produce,
          ),
        ],
      );

      await controller.addPlannedMeal(mealA);
      await controller.addPlannedMeal(mealB);

      expect(controller.hasPlannedMealsForDate(date), isTrue);
      expect(
        controller.getPlannedMealsByType(date, 'dinner').single.name,
        'Pasta',
      );
      expect(controller.getPlannedTotalsForDate(date).calories, 900);

      final shopping = controller.generateShoppingList(date, date);
      expect(shopping.single.name, 'Tomato');
      expect(shopping.single.totalAmount, 3);
      expect(shopping.single.isChecked, isFalse);

      await controller.toggleShoppingItem('Tomato', 'pcs');
      expect(controller.isShoppingItemChecked('tomato', 'pcs'), isTrue);
      expect(storage.loadShoppingListChecked(), contains('tomato_pcs'));

      await controller.removePlannedMeal('meal-b');
      expect(controller.getPlannedTotalsForDate(date).calories, 600);
      expect(changes, 4);
    });

    test('managed recipes, custom foods, favorites, and portions', () async {
      final storage = await createTestStorage();
      var changes = 0;
      final controller = FoodLibraryController(storage, () => changes += 1);
      final timestamp = DateTime(2026, 1, 2);
      final recipe = Recipe(
        id: 'recipe-1',
        name: 'Chili',
        ingredients: const [],
        createdAt: timestamp,
      );
      const food = FoodItem(
        id: 'food-1',
        name: 'Greek Yogurt',
        category: 'dairy',
        caloriesPer100g: 90,
        proteinPer100g: 10,
        carbsPer100g: 4,
        fatPer100g: 2,
      );
      final portion = CustomPortion(
        id: 'portion-1',
        productKey: 'name:greek yogurt',
        name: 'Cup',
        grams: 150,
        createdAt: timestamp,
      );

      await controller.addRecipe(recipe);
      await controller.updateRecipe(recipe.copyWith(name: 'Bean Chili'));
      await controller.addCustomFood(food);
      await controller.addCustomFood(food);
      await controller.toggleFavorite(food);
      await controller.addCustomPortion(portion);

      expect(controller.recipes.single.name, 'Bean Chili');
      expect(controller.customFoods, hasLength(1));
      expect(controller.searchCustomFoods('yog').single.id, 'food-1');
      expect(controller.isFavorite('food-1'), isTrue);
      expect(controller.favoriteFoods.single.isFavorite, isTrue);
      expect(controller.getCustomPortionsForProduct('name:greek yogurt'), [
        portion,
      ]);

      await controller.toggleFavorite(food);
      await controller.removeCustomFood('food-1');
      await controller.removeRecipe('recipe-1');
      await controller.removeCustomPortion('portion-1');

      expect(controller.recipes, isEmpty);
      expect(controller.customFoods, isEmpty);
      expect(controller.favoriteFoods, isEmpty);
      expect(controller.customPortions, isEmpty);
      expect(changes, 9);
    });
  });
}
