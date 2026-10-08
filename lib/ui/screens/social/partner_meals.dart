import 'package:flutter/material.dart';

import 'package:sophis/models/social/social_snapshot.dart';
import 'package:sophis/models/custom_meal_type.dart';
import 'package:sophis/ui/components/organic_components.dart';
import 'package:sophis/ui/theme/app_theme.dart';

/// Uses the author's category rather than guessing from the food or time.
class PartnerMeals extends StatelessWidget {
  final List<Map<String, dynamic>> meals;
  final ValueChanged<Map<String, dynamic>>? onImport;

  const PartnerMeals({super.key, required this.meals, this.onImport});

  @override
  Widget build(BuildContext context) {
    final categories = [
      for (final meal in CustomMealType.defaults)
        (meal.id, meal.name, meal.icon, meal.color),
    ];
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final meal in meals) {
      final category = meal['mealCategory'] as String? ?? 'other';
      final key = category == 'snacks' ? 'snack' : category;
      groups.putIfAbsent(key, () => []).add(meal);
    }
    return Column(
      children: [
        for (final category in [
          ...categories,
          for (final key in groups.keys.where(
            (key) => !categories.any((category) => category.$1 == key),
          ))
            (
              key,
              key == 'other' ? 'Other meals' : key,
              Icons.restaurant_outlined,
              Theme.of(context).colorScheme.primary,
            ),
        ])
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.spaceSM2),
            child: _buildMeal(
              context,
              category.$2,
              category.$3,
              category.$4,
              groups[category.$1] ?? const [],
            ),
          ),
      ],
    );
  }

  Widget _buildMeal(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<Map<String, dynamic>> records,
  ) {
    final snapshots = [
      for (final record in records)
        SocialSnapshot.fromJson(
          record['snapshot'] as Map<String, dynamic>,
          nutritionVisible: true,
        ),
    ];
    return MealCard(
      title: title,
      icon: icon,
      color: color,
      calories: snapshots
          .expand((snapshot) => snapshot.items)
          .fold(0.0, (total, item) => total + item.calories),
      showHeaderChevron: false,
      emptyLabel: 'No shared items',
      entries: [
        for (var index = 0; index < records.length; index++)
          for (final item in snapshots[index].items)
            FoodEntryTile(
              name: item.name,
              calories: item.calories,
              protein: item.protein,
              carbs: item.carbs,
              fat: item.fat,
              fiber: item.fiber,
              onTap: onImport == null ? null : () => onImport!(records[index]),
            ),
      ],
    );
  }
}
