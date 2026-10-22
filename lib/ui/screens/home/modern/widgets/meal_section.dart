import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/components/organic_components.dart';
import 'package:sophis/ui/screens/meal_detail_screen.dart';
import 'package:sophis/ui/components/quick_add_sheet.dart';
import 'package:sophis/ui/components/repeat_meal_button.dart';

/// A meal section (e.g., Breakfast, Lunch) with food entries.
class MealSection extends StatelessWidget {
  final String mealType;
  final String title;
  final IconData icon;
  final Color? color;
  final bool showMacros;

  const MealSection({
    super.key,
    required this.mealType,
    required this.title,
    required this.icon,
    this.color,
    required this.showMacros,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<NutritionProvider, List<FoodEntry>>(
      selector: (_, n) => n.getEntriesByMeal(mealType),
      builder: (context, entries, _) {
        return _MealSectionContent(
          mealType: mealType,
          title: title,
          icon: icon,
          color: color,
          showMacros: showMacros,
          entries: entries,
        );
      },
    );
  }
}

class _MealSectionContent extends StatelessWidget {
  final String mealType;
  final String title;
  final IconData icon;
  final Color? color;
  final bool showMacros;
  final List<FoodEntry> entries;

  const _MealSectionContent({
    required this.mealType,
    required this.title,
    required this.icon,
    this.color,
    required this.showMacros,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final mealColor = color ??
        context.select<SettingsProvider, Color?>(
          (s) => s.getMealType(mealType)?.color,
        ) ??
        theme.colorScheme.primary;

    var total = 0.0;
    var totalProtein = 0.0;
    var totalCarbs = 0.0;
    var totalFat = 0.0;
    var totalFiber = 0.0;
    for (final entry in entries) {
      total += entry.calories;
      totalProtein += entry.protein;
      totalCarbs += entry.carbs;
      totalFat += entry.fat;
      totalFiber += entry.fiber;
    }

    return MealCard(
      title: title,
      icon: icon,
      calories: total,
      color: mealColor,
      showMacros: showMacros,
      protein: totalProtein,
      carbs: totalCarbs,
      fat: totalFat,
      fiber: totalFiber,
      showHeaderChevron: entries.isNotEmpty,
      onHeaderTap: entries.isEmpty
          ? () => showQuickAddSheet(context, mealType: mealType)
          : () => Navigator.push(
                context,
                AppTheme.slideRoute(
                  MealDetailScreen(
                    mealType: mealType,
                    mealTitle: title,
                    mealIcon: icon,
                  ),
                ),
              ),
      addMenu: _buildAddMenu(context, l10n, theme, entries),
      entries: entries
          .map((entry) => _buildEntryTile(context, l10n, entry))
          .toList(),
    );
  }

  Widget _buildAddMenu(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    List<FoodEntry> entries,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepeatMealButton(meal: mealType),
        IconButton(
          icon:
              Icon(Icons.add_circle_outline, color: theme.colorScheme.primary),
          tooltip: l10n.add,
          onPressed: () => showQuickAddSheet(context, mealType: mealType),
        ),
      ],
    );
  }

  Widget _buildEntryTile(
    BuildContext context,
    AppLocalizations l10n,
    FoodEntry entry,
  ) {
    return FoodEntryTile(
      key: ValueKey(entry.id),
      name: entry.name,
      calories: entry.calories,
      protein: entry.protein,
      carbs: entry.carbs,
      fat: entry.fat,
      fiber: entry.fiber,
      onTap: () => showFoodEntryEditor(context, entry),
      onLongPress: () => showFoodEntryActions(context, entry),
    );
  }
}
