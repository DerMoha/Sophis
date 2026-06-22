import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/custom_portion.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/meal_plan.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/nutrition_totals.dart';
import 'package:sophis/models/progress_photo.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/models/serving_size.dart';
import 'package:sophis/models/shareable_meal.dart';
import 'package:sophis/models/supplement.dart';
import 'package:sophis/models/user_profile.dart';
import 'package:sophis/models/user_stats.dart';
import 'package:sophis/models/weight_entry.dart';
import 'package:sophis/models/workout_entry.dart';

void main() {
  group('Nutrition domain models', () {
    test('calculated default goals from calorie target', () {
      final goals = NutritionGoals(calories: 2000);

      expect(goals.protein, 150);
      expect(goals.carbs, 200);
      expect(goals.fat, closeTo(66.6667, 0.0001));
      expect(goals.fiber, 28);
    });

    test('round-tripped nutrition goals and totals', () {
      final goals = NutritionGoals(
        calories: 2200,
        protein: 160,
        carbs: 230,
        fat: 70,
        fiber: 32,
      );
      final restoredGoals = NutritionGoals.fromJson(goals.toJson());

      expect(restoredGoals.calories, 2200);
      expect(restoredGoals.protein, 160);
      expect(restoredGoals.carbs, 230);
      expect(restoredGoals.fat, 70);
      expect(restoredGoals.fiber, 32);

      const totals = NutritionTotals(
        calories: 100,
        protein: 10,
        carbs: 20,
        fat: 5,
        fiber: 3,
      );
      final doubled = totals * 2;
      final summed = totals + const NutritionTotals(calories: 50, protein: 5);

      expect(doubled.carbs, 40);
      expect(summed.calories, 150);
      expect(NutritionTotals.zero.isEmpty, isTrue);
    });

    test('calculated user profile BMR, TDEE, and suggested calories', () {
      const profile = UserProfile(
        weight: 80,
        height: 180,
        age: 30,
        gender: Gender.male,
        activityLevel: ActivityLevel.moderate,
        goal: Goal.lose,
        targetWeight: 75,
      );

      expect(profile.bmr, 1780);
      expect(profile.tdee, 2759);
      expect(profile.suggestedCalories, 2259);

      final restored = UserProfile.fromJson(profile.toJson());
      expect(restored.gender, Gender.male);
      expect(restored.activityLevel, ActivityLevel.moderate);
      expect(restored.goal, Goal.lose);
      expect(restored.targetWeight, 75);
    });

    test('summed recipes and divided them per serving', () {
      final createdAt = DateTime(2026, 1, 2);
      final recipe = Recipe(
        id: 'recipe-1',
        name: 'Chili',
        servings: 2,
        createdAt: createdAt,
        ingredients: const [
          RecipeIngredient(
            id: 'beans',
            name: 'Beans',
            amountGrams: 200,
            calories: 240,
            protein: 16,
            carbs: 40,
            fat: 1,
            fiber: 14,
          ),
          RecipeIngredient(
            id: 'rice',
            name: 'Rice',
            amountGrams: 150,
            calories: 180,
            protein: 4,
            carbs: 38,
            fat: 1,
            fiber: 1,
          ),
        ],
      );

      expect(recipe.totalNutrients.calories, 420);
      expect(recipe.totalNutrients.fiber, 15);
      expect(recipe.nutrientsPerServing.calories, 210);
      expect(recipe.nutrientsPerServing.protein, 10);

      final restored = Recipe.fromJson(recipe.toJson());
      expect(restored.name, 'Chili');
      expect(restored.createdAt, createdAt);
      expect(restored.ingredients, hasLength(2));
    });

    test('round-tripped planned meals and normalized date', () {
      final date = DateTime(2026, 1, 2, 19, 30);
      final meal = PlannedMeal(
        id: 'planned-1',
        date: date,
        meal: 'dinner',
        name: 'Pasta',
        calories: 600,
        protein: 24,
        carbs: 80,
        fat: 18,
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

      final restored = PlannedMeal.fromJson(meal.toJson());

      expect(restored.normalizedDate, DateTime(2026, 1, 2));
      expect(restored.ingredients.single.name, 'Tomato');
      expect(restored.fiber, 8);
    });

    test('encoded and parsed shareable meals', () {
      final entry = FoodEntry(
        id: 'entry-1',
        name: 'Bowl',
        calories: 500,
        protein: 35,
        carbs: 50,
        fat: 16,
        fiber: 7,
        timestamp: DateTime(2026, 1, 2),
        meal: 'lunch',
      );
      final meal = ShareableMeal.fromFoodEntries([entry], title: 'Lunch Bowl');
      final decoded = ShareableMeal.fromEncodedString(meal.toEncodedString());
      final fromLink = ShareableMeal.fromDeepLink(meal.toDeepLink());

      expect(decoded.title, 'Lunch Bowl');
      expect(decoded.totalCalories, 500);
      expect(decoded.totalFiber, 7);
      expect(fromLink?.items.single.name, 'Bowl');
      expect(ShareableMeal.fromDeepLink('https://example.com'), isNull);
    });

    test('generated serving fractions and custom portion keys', () {
      final servings = ServingSize.generateFractions('cup', 240);

      expect(servings.map((serving) => serving.name), [
        '1/4 cup',
        '1/2 cup',
        '3/4 cup',
        '1 cup',
        '1.5 cup',
        '2 cup',
      ]);
      expect(servings[1].grams, 120);
      expect(
        CustomPortion.createProductKey(barcode: '123', name: 'Milk'),
        'barcode:123',
      );
      expect(
        CustomPortion.createProductKey(name: '  Greek Yogurt  '),
        'name:greek yogurt',
      );
    });

    test('round-tripped secondary tracking models', () {
      final timestamp = DateTime(2026, 1, 2, 8, 30);
      final createdAt = DateTime(2026, 1, 1);
      final supplement = Supplement(
        id: 'supplement-1',
        name: 'Vitamin D',
        reminderTime: '09:00',
        createdAt: createdAt,
      );
      final photo = ProgressPhoto(
        id: 'photo-1',
        imagePath: '/tmp/photo.jpg',
        timestamp: timestamp,
        weightKg: 80,
        note: 'Start',
        category: PhotoCategory.side,
        createdAt: createdAt,
      );
      final weight = WeightEntry(
        id: 'weight-1',
        weightKg: 80,
        timestamp: timestamp,
        note: 'Morning',
      );
      final workout = WorkoutEntry(
        id: 'workout-1',
        caloriesBurned: 350,
        timestamp: timestamp,
        note: 'Run',
      );
      final stats = UserStats(
        currentStreak: 3,
        longestStreak: 4,
        lastLogDate: timestamp,
        achievements: const [Achievements.firstLog],
        totalDaysLogged: 5,
      );

      expect(Supplement.fromJson(supplement.toJson()).reminderTime, '09:00');
      expect(
        ProgressPhoto.fromJson(photo.toJson()).category,
        PhotoCategory.side,
      );
      expect(WeightEntry.fromJson(weight.toJson()).source, 'manual');
      expect(WorkoutEntry.fromJson(workout.toJson()).note, 'Run');
      expect(UserStats.fromJson(stats.toJson()).achievements, [
        Achievements.firstLog,
      ]);
    });

    test('calculated food item nutrition for arbitrary grams', () {
      const item = FoodItem(
        id: 'oats',
        name: 'Oats',
        category: 'grains',
        caloriesPer100g: 380,
        proteinPer100g: 13,
        carbsPer100g: 67,
        fatPer100g: 7,
        fiberPer100g: 10,
      );

      final nutrients = item.calculateFor(50);

      expect(nutrients.calories, 190);
      expect(nutrients.protein, 6.5);
      expect(nutrients.carbs, 33.5);
      expect(nutrients.fiber, 5);
    });
  });
}
