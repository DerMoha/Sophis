import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/nutrition_totals.dart';
import 'package:sophis/models/app_settings.dart';
import 'package:sophis/models/custom_meal_type.dart';
import 'package:sophis/providers/nutrition_provider.dart';

/// Immutable view model containing all derived dashboard values.
class HomeDashboardVM {
  final NutritionTotals totals;
  final NutritionGoals goals;
  final double remaining;
  final double burnedCalories;
  final double effectiveGoal;
  final double calorieProgress;
  final double waterTotal;
  final double waterGoal;
  final UnitSystem unitSystem;
  final List<CustomMealType> mealTypes;
  final bool showMealMacros;
  final bool healthSyncEnabled;
  final List<DashboardCard> visibleDashboardCards;
  final QuickActionSize quickActionSize;

  const HomeDashboardVM({
    required this.totals,
    required this.goals,
    required this.remaining,
    required this.burnedCalories,
    required this.effectiveGoal,
    required this.calorieProgress,
    required this.waterTotal,
    required this.waterGoal,
    required this.unitSystem,
    required this.mealTypes,
    required this.showMealMacros,
    required this.healthSyncEnabled,
    required this.visibleDashboardCards,
    required this.quickActionSize,
  });

  bool get isOverGoal => remaining < 0;
}

/// Builds a HomeDashboardVM from providers.
/// Settings values must be pre-selected by the caller.
HomeDashboardVM buildHomeDashboardVM(
  NutritionProvider nutrition, {
  required double waterGoalMl,
  required UnitSystem unitSystem,
  required List<CustomMealType> mealTypes,
  required bool showMealMacros,
  required bool healthSyncEnabled,
  required List<DashboardCard> visibleDashboardCards,
  required QuickActionSize quickActionSize,
}) {
  final totals = nutrition.getTodayTotals();
  final goals = nutrition.goals!;
  final burned = nutrition.burnedCalories;
  final effectiveGoal = goals.calories + burned;
  final remaining = effectiveGoal - totals.calories;

  return HomeDashboardVM(
    totals: totals,
    goals: goals,
    remaining: remaining,
    burnedCalories: burned,
    effectiveGoal: effectiveGoal,
    calorieProgress: (totals.calories / effectiveGoal).clamp(0.0, 1.0),
    waterTotal: nutrition.getTodayWaterTotal(),
    waterGoal: waterGoalMl,
    unitSystem: unitSystem,
    mealTypes: mealTypes,
    showMealMacros: showMealMacros,
    healthSyncEnabled: healthSyncEnabled,
    visibleDashboardCards: visibleDashboardCards,
    quickActionSize: quickActionSize,
  );
}
