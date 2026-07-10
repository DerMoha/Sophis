import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sophis/models/app_settings.dart';
import 'package:sophis/models/custom_meal_type.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/nutrition_totals.dart';
import 'package:sophis/models/user_stats.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/ui/screens/home/shared/dashboard_slot.dart';

/// Immutable view model containing all derived dashboard values.
///
/// Most fields are pure pass-throughs of provider data; the VM exists so the
/// screen does not need to wire 7 separate `context.select` calls and can be
/// passed as a single struct into the slot-building logic.
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
  final UserStats userStats;
  final bool showSupplements;

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
    required this.userStats,
    required this.showSupplements,
  });

  bool get isOverGoal => remaining < 0;

  /// Streak is only shown on the dashboard when it reaches a meaningful
  /// threshold. The screen-side check used to live inside the [StreakCard]
  /// widget, which made layout spacing unpredictable.
  bool get hasVisibleStreak => userStats.currentStreak >= 2;
}

/// Builds a [HomeDashboardVM] from the live providers. All values the VM
/// needs are read with `context.select`/`watch` so callers get a fresh VM
/// whenever any input changes.
///
/// Use this rather than the historical `buildHomeDashboardVM` function: the
/// screen now drives the dashboard from `buildDashboardSlots(context)` which
/// uses the VM only for data.
HomeDashboardVM readHomeDashboardVM(BuildContext context) {
  final nutrition = context.read<NutritionProvider>();
  final settings = context.read<SettingsProvider>();

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
    waterGoal: settings.waterGoalMl,
    unitSystem: settings.unitSystem,
    mealTypes: settings.mealTypes,
    showMealMacros: settings.showMealMacros,
    healthSyncEnabled: settings.healthSyncEnabled,
    visibleDashboardCards: settings.visibleDashboardCards,
    quickActionSize: settings.quickActionSize,
    userStats: nutrition.userStats,
    showSupplements: settings.showSupplements,
  );
}

/// Builds the ordered list of [DashboardSlot]s the home screen should render,
/// given the current providers and VM. Visibility decisions (streak threshold,
/// supplements toggle, empty quick actions) live here so the parent screen
/// can reserve space correctly and animation indices stay stable.
List<DashboardSlot> buildDashboardSlots(
  BuildContext context,
  HomeDashboardVM vm,
) {
  final slots = <DashboardSlot>[];

  // 1. Calorie hero
  slots.add(
    DashboardCalorieHero(
      consumed: vm.totals.calories,
      baseGoal: vm.goals.calories.toDouble(),
      effectiveGoal: vm.effectiveGoal,
      remaining: vm.remaining,
      progress: vm.calorieProgress,
      burnedCalories: vm.burnedCalories,
    ),
  );
  slots.add(const DashboardSpace(12));

  // 2. Compact macro summary
  slots.add(DashboardMacros(totals: vm.totals, goals: vm.goals));
  slots.add(const DashboardSpace(24));

  // 3. Today's meals. Secondary trackers live under More.
  slots.add(const DashboardMealHeader());
  for (var i = 0; i < vm.mealTypes.length; i++) {
    final mealType = vm.mealTypes[i];
    slots.add(
      DashboardMealSection(
        mealType: mealType,
        showMacros: vm.showMealMacros,
      ),
    );
    if (i < vm.mealTypes.length - 1) {
      slots.add(const DashboardSpace(12));
    }
  }

  return slots;
}

/// Legacy API kept for the test suite. Prefer [readHomeDashboardVM] +
/// [buildDashboardSlots] in new code.
HomeDashboardVM buildHomeDashboardVM(
  NutritionProvider nutrition, {
  required double waterGoalMl,
  required UnitSystem unitSystem,
  required List<CustomMealType> mealTypes,
  required bool showMealMacros,
  required bool healthSyncEnabled,
  required List<DashboardCard> visibleDashboardCards,
  required QuickActionSize quickActionSize,
  required UserStats userStats,
  required bool showSupplements,
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
    userStats: userStats,
    showSupplements: showSupplements,
  );
}
