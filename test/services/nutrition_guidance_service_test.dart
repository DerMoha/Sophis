import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/meal_plan.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/nutrition_totals.dart';
import 'package:sophis/models/serving_size.dart';
import 'package:sophis/models/weight_entry.dart';
import 'package:sophis/services/nutrition_guidance_service.dart';

void main() {
  const service = NutritionGuidanceService();

  group('NutritionGuidanceService', () {
    test('returns an actionable no-goal state', () {
      final guidance = service.calculateDaily(
        consumed: const NutritionTotals(calories: 400, protein: 20),
        goals: null,
        burnedCalories: 0,
        remainingMealSlots: 2,
        plannedMeals: const [],
        recentFoods: const [],
      );

      expect(guidance.hasGoal, isFalse);
      expect(guidance.fittingPlannedMeals, isEmpty);
    });

    test('calculates remaining budget and filters fitting choices', () {
      final planned = [
        PlannedMeal(
          id: 'fits',
          date: DateTime(2026, 1, 5),
          meal: 'dinner',
          name: 'Chicken bowl',
          calories: 500,
          protein: 35,
          carbs: 40,
          fat: 12,
        ),
        PlannedMeal(
          id: 'too-large',
          date: DateTime(2026, 1, 5),
          meal: 'dinner',
          name: 'Large pasta',
          calories: 900,
          protein: 40,
          carbs: 110,
          fat: 25,
        ),
      ];
      const recent = [
        FoodItem(
          id: 'yogurt',
          name: 'Yogurt',
          category: 'dairy',
          caloriesPer100g: 70,
          proteinPer100g: 10,
          carbsPer100g: 4,
          fatPer100g: 1,
          servings: [ServingSize(name: 'cup', grams: 150)],
        ),
      ];

      final guidance = service.calculateDaily(
        consumed: const NutritionTotals(calories: 1200, protein: 50),
        goals: NutritionGoals(calories: 1800, protein: 100),
        burnedCalories: 200,
        remainingMealSlots: 2,
        plannedMeals: planned,
        recentFoods: recent,
      );

      expect(guidance.remainingCalories, 800);
      expect(guidance.remainingProtein, 50);
      expect(guidance.suggestedCaloriesPerSlot, 400);
      expect(guidance.suggestedProteinPerSlot, 25);
      expect(guidance.fittingPlannedMeals.single.name, 'Chicken bowl');
      expect(guidance.fittingRecentFoods.single.name, 'Yogurt');
    });

    test('keeps over-goal state non-negative for suggestions', () {
      final guidance = service.calculateDaily(
        consumed: const NutritionTotals(calories: 2200, protein: 120),
        goals: NutritionGoals(calories: 2000, protein: 100),
        burnedCalories: 0,
        remainingMealSlots: 1,
        plannedMeals: const [],
        recentFoods: const [],
      );

      expect(guidance.isOverGoal, isTrue);
      expect(guidance.remainingCalories, -200);
      expect(guidance.suggestedCaloriesPerSlot, 0);
      expect(guidance.suggestedProteinPerSlot, 0);
    });

    test('summarizes seven-day history and weight trend', () {
      final reference = DateTime(2026, 1, 7, 18);
      final entries = [
        FoodEntry(
          id: 'day-1',
          name: 'Breakfast',
          calories: 2000,
          protein: 100,
          carbs: 200,
          fat: 60,
          timestamp: DateTime(2026, 1, 5, 8),
          meal: 'breakfast',
        ),
        FoodEntry(
          id: 'day-2',
          name: 'Dinner',
          calories: 1800,
          protein: 90,
          carbs: 160,
          fat: 55,
          timestamp: DateTime(2026, 1, 7, 19),
          meal: 'dinner',
        ),
      ];
      final weights = [
        WeightEntry(
          id: 'weight-1',
          weightKg: 80,
          timestamp: DateTime(2026, 1, 2, 8),
        ),
        WeightEntry(
          id: 'weight-2',
          weightKg: 79.2,
          timestamp: DateTime(2026, 1, 7, 8),
        ),
      ];

      final review = service.calculateWeekly(
        entries: entries,
        weights: weights,
        goals: NutritionGoals(calories: 1900),
        referenceDate: reference,
      );

      expect(review.average.calories, closeTo(3800 / 7, 0.001));
      expect(review.average.protein, closeTo(190 / 7, 0.001));
      expect(review.loggedDays, 2);
      expect(review.goalHitDays, 2);
      expect(review.weightTrendKg, closeTo(-0.8, 0.001));
      expect(review.hasEnoughHistory, isFalse);
    });
  });
}
