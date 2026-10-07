import 'dart:math' as math;

import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/nutrition_totals.dart';
import 'package:sophis/models/portion_selection.dart';
import 'package:sophis/models/meal_plan.dart';
import 'package:sophis/models/weight_entry.dart';

/// Deterministic daily suggestions. There is no AI or network dependency in
/// this class, which keeps dashboard guidance predictable and testable.
class NutritionGuidance {
  final bool hasGoal;
  final bool isOverGoal;
  final double remainingCalories;
  final double remainingProtein;
  final double suggestedCaloriesPerSlot;
  final double suggestedProteinPerSlot;
  final List<PlannedMeal> fittingPlannedMeals;
  final List<FoodItem> fittingRecentFoods;

  const NutritionGuidance({
    required this.hasGoal,
    required this.isOverGoal,
    required this.remainingCalories,
    required this.remainingProtein,
    required this.suggestedCaloriesPerSlot,
    required this.suggestedProteinPerSlot,
    required this.fittingPlannedMeals,
    required this.fittingRecentFoods,
  });

  static const noGoal = NutritionGuidance(
    hasGoal: false,
    isOverGoal: false,
    remainingCalories: 0,
    remainingProtein: 0,
    suggestedCaloriesPerSlot: 0,
    suggestedProteinPerSlot: 0,
    fittingPlannedMeals: [],
    fittingRecentFoods: [],
  );
}

class NutritionGuidanceService {
  const NutritionGuidanceService();

  NutritionGuidance calculateDaily({
    required NutritionTotals consumed,
    required NutritionGoals? goals,
    required double burnedCalories,
    required int remainingMealSlots,
    required List<PlannedMeal> plannedMeals,
    required List<FoodItem> recentFoods,
  }) {
    if (goals == null) return NutritionGuidance.noGoal;

    final effectiveCalories = goals.calories + burnedCalories;
    final rawRemainingCalories = effectiveCalories - consumed.calories;
    final rawRemainingProtein = goals.protein - consumed.protein;
    final slots = math.max(1, remainingMealSlots);
    final calorieBudget = math.max(0, rawRemainingCalories).toDouble();
    final proteinBudget = math.max(0, rawRemainingProtein).toDouble();

    final fittingPlanned = plannedMeals
        .where(
          (meal) =>
              meal.calories <= calorieBudget + 0.01 &&
              meal.protein <= proteinBudget + 0.01,
        )
        .take(3)
        .toList(growable: false);

    final fittingRecent = recentFoods
        .where((food) {
          final selection = _defaultSelection(food);
          final nutrition = food.calculateForSelection(selection);
          return nutrition.calories <= calorieBudget + 0.01 &&
              nutrition.protein <= proteinBudget + 0.01;
        })
        .take(4)
        .toList(growable: false);

    return NutritionGuidance(
      hasGoal: true,
      isOverGoal: rawRemainingCalories < 0,
      remainingCalories: rawRemainingCalories,
      remainingProtein: rawRemainingProtein,
      suggestedCaloriesPerSlot: calorieBudget / slots,
      suggestedProteinPerSlot: proteinBudget / slots,
      fittingPlannedMeals: fittingPlanned,
      fittingRecentFoods: fittingRecent,
    );
  }

  WeeklyNutritionReview calculateWeekly({
    required List<FoodEntry> entries,
    required List<WeightEntry> weights,
    required NutritionGoals? goals,
    DateTime? referenceDate,
  }) {
    final reference = _day(referenceDate ?? DateTime.now());
    final start = reference.subtract(const Duration(days: 6));
    final daily = <DateTime, NutritionTotals>{};
    for (final entry in entries) {
      final day = _day(entry.timestamp);
      if (day.isBefore(start) || day.isAfter(reference)) continue;
      daily[day] = (daily[day] ?? NutritionTotals.zero) +
          NutritionTotals(
            calories: entry.calories,
            protein: entry.protein,
            carbs: entry.carbs,
            fat: entry.fat,
            fiber: entry.fiber,
          );
    }

    var total = NutritionTotals.zero;
    var goalHitDays = 0;
    for (var index = 0; index < 7; index++) {
      final day = start.add(Duration(days: index));
      final value = daily[day] ?? NutritionTotals.zero;
      total += value;
      if (goals != null &&
          value.calories >= goals.calories * 0.9 &&
          value.calories <= goals.calories * 1.1) {
        goalHitDays++;
      }
    }

    final windowWeights = weights.where((weight) {
      final day = _day(weight.timestamp);
      return !day.isBefore(start) && !day.isAfter(reference);
    }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final weightTrendKg = windowWeights.length >= 2
        ? windowWeights.last.weightKg - windowWeights.first.weightKg
        : null;

    return WeeklyNutritionReview(
      average: total * (1 / 7),
      loggedDays: daily.length,
      goalHitDays: goals == null ? 0 : goalHitDays,
      weightTrendKg: weightTrendKg,
      hasEnoughHistory: daily.length >= 3,
    );
  }

  PortionSelection _defaultSelection(FoodItem food) {
    final remembered = food.lastUsedPortion;
    if (remembered != null &&
        remembered.unit == food.nutritionUnit &&
        remembered.isValid) {
      return remembered;
    }
    for (final serving in food.servings) {
      if (serving.unit == food.nutritionUnit &&
          (serving.multiplier - 1).abs() < 0.001 &&
          serving.selection.isValid) {
        return serving.selection;
      }
    }
    return PortionSelection(amount: 100, unit: food.nutritionUnit);
  }

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);
}

class WeeklyNutritionReview {
  final NutritionTotals average;
  final int loggedDays;
  final int goalHitDays;
  final double? weightTrendKg;
  final bool hasEnoughHistory;

  const WeeklyNutritionReview({
    required this.average,
    required this.loggedDays,
    required this.goalHitDays,
    required this.weightTrendKg,
    required this.hasEnoughHistory,
  });

  double get goalHitRate => goalHitDays / 7;
}
