import 'package:flutter/material.dart';
import 'package:sophis/ui/components/common/entry_feedback.dart';
import 'package:sophis/ui/components/quick_add_sheet.dart';
import 'package:provider/provider.dart';

import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/shareable_meal.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/screens/share_meal_screen.dart';

void shareMealEntries(
  BuildContext context,
  List<FoodEntry> entries, {
  String? title,
}) {
  final meal = ShareableMeal.fromFoodEntries(entries, title: title);
  Navigator.push(context, AppTheme.slideRoute(ShareMealScreen(meal: meal)));
}

Future<void> showMealAddOptionsSheet(
  BuildContext context, {
  required String mealType,
}) =>
    showQuickAddSheet(context, mealType: mealType);

Future<void> deleteFoodEntryWithUndo(
  BuildContext context, {
  required FoodEntry entry,
}) {
  final nutrition = context.read<NutritionProvider>();
  return deleteEntryWithUndo(
    context,
    remove: () => nutrition.removeFoodEntry(entry.id),
    restore: () => nutrition.addFoodEntry(entry),
    label: entry.name,
  );
}
