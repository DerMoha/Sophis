import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/nutrition_totals.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/models/custom_meal_type.dart';

/// View model for the FoodDiaryScreen.
class FoodDiaryVM {
  final DateTime date;
  final List<FoodEntry> entries;
  final Map<String, List<FoodEntry>> entriesByMeal;
  final NutritionTotals totals;
  final NutritionGoals? goals;
  final List<CustomMealType> mealTypes;

  const FoodDiaryVM({
    required this.date,
    required this.entries,
    required this.entriesByMeal,
    required this.totals,
    required this.goals,
    required this.mealTypes,
  });

  bool get isEmpty => entries.isEmpty;
}

/// Builds a FoodDiaryVM for the given date.
FoodDiaryVM buildFoodDiaryVM(
  BuildContext context,
  NutritionProvider nutrition,
  DateTime date,
) {
  final settings = context.read<SettingsProvider>();
  final entries = nutrition.getEntriesForDate(date);
  final entriesByMeal = <String, List<FoodEntry>>{};
  for (final entry in entries) {
    entriesByMeal.putIfAbsent(entry.meal, () => []).add(entry);
  }

  return FoodDiaryVM(
    date: date,
    entries: entries,
    entriesByMeal: entriesByMeal,
    totals: _calculateTotals(entries),
    goals: nutrition.goals,
    mealTypes: settings.mealTypes,
  );
}

NutritionTotals _calculateTotals(List<FoodEntry> entries) {
  double calories = 0, protein = 0, carbs = 0, fat = 0;
  for (final entry in entries) {
    calories += entry.calories;
    protein += entry.protein;
    carbs += entry.carbs;
    fat += entry.fat;
  }
  return NutritionTotals(
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
  );
}

/// Formats a date as a day name (Today, Yesterday, or weekday).
String getDayName(
  DateTime date,
  String todayLabel,
  String yesterdayLabel,
  String locale,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dateNorm = DateTime(date.year, date.month, date.day);

  if (dateNorm == today) return todayLabel;
  if (dateNorm == today.subtract(const Duration(days: 1))) {
    return yesterdayLabel;
  }
  return DateFormat.E(locale).format(date);
}

/// Formats a date as a full date string.
String getFormattedDate(DateTime date, String locale) {
  return DateFormat.yMMMMd(locale).format(date);
}
