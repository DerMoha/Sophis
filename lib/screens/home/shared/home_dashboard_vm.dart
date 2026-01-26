import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../../models/nutrition_goals.dart';
import '../../../models/app_settings.dart';
import '../../../models/custom_meal_type.dart';
import '../../../services/nutrition_provider.dart';
import '../../../services/settings_provider.dart';

/// Immutable view model containing all derived dashboard values.
/// Avoids repeated calculations in both modern and legacy screens.
class HomeDashboardVM {
  final Map<String, double> totals;
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
/// Call this once at the top of your build method.
HomeDashboardVM buildHomeDashboardVM(
  BuildContext context,
  NutritionProvider nutrition,
) {
  final settings = context.watch<SettingsProvider>();
  final totals = nutrition.getTodayTotals();
  final goals = nutrition.goals!;
  final burned = nutrition.burnedCalories;
  final effectiveGoal = goals.calories + burned;

  return HomeDashboardVM(
    totals: totals,
    goals: goals,
    remaining: nutrition.getRemainingCalories(),
    burnedCalories: burned,
    effectiveGoal: effectiveGoal,
    calorieProgress: (totals['calories']! / effectiveGoal).clamp(0.0, 1.0),
    waterTotal: nutrition.getTodayWaterTotal(),
    waterGoal: settings.waterGoalMl,
    unitSystem: settings.unitSystem,
    mealTypes: settings.mealTypes,
    showMealMacros: settings.showMealMacros,
    healthSyncEnabled: settings.healthSyncEnabled,
    visibleDashboardCards: settings.visibleDashboardCards,
    quickActionSize: settings.quickActionSize,
  );
}
