import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/models/portion_selection.dart';

/// A reusable meal made up of food snapshots and explicit portions.
///
/// Keeping the food snapshot in the template means editing a product later
/// cannot rewrite the nutrition of a saved repeat action.
class MealTemplateItem {
  final FoodItem food;
  final PortionSelection selection;
  final String meal;

  const MealTemplateItem({
    required this.food,
    required this.selection,
    required this.meal,
  });

  Map<String, dynamic> toJson() => {
        'food': food.toJson(),
        'selection': selection.toJson(),
        'meal': meal,
      };

  factory MealTemplateItem.fromJson(Map<String, dynamic> json) =>
      MealTemplateItem(
        food: FoodItem.fromJson(json['food'] as Map<String, dynamic>),
        selection: PortionSelection.fromJson(
          json['selection'] as Map<String, dynamic>,
        ),
        meal: json['meal'] as String? ?? 'snack',
      );
}

class MealTemplate {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<MealTemplateItem> items;

  const MealTemplate({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.items,
  });

  /// Creates a self-contained template from historical entry snapshots.
  ///
  /// Entries from before portion metadata existed are represented as an
  /// explicit 100 g snapshot, preserving their historical macros without
  /// inventing a serving conversion.
  factory MealTemplate.fromEntries({
    required String id,
    required String name,
    required DateTime createdAt,
    required List<FoodEntry> entries,
  }) {
    final items = <MealTemplateItem>[];
    for (final entry in entries) {
      final selection = entry.portionSelection ??
          const PortionSelection(amount: 100, unit: NutritionUnit.gram);
      if (!selection.isValid) continue;
      final factor = selection.amount / 100;
      final oldSuffix = ' (${entry.displayPortionText})';
      final displayName = entry.name.endsWith(oldSuffix)
          ? entry.name.substring(0, entry.name.length - oldSuffix.length)
          : entry.name.replaceFirst(
              RegExp(r'\s*\([^)]*\)\s*$'),
              '',
            );
      items.add(
        MealTemplateItem(
          food: FoodItem(
            id: entry.sourceFoodId ?? 'template:${entry.id}',
            name: displayName,
            category: 'template',
            caloriesPer100g: entry.calories / factor,
            proteinPer100g: entry.protein / factor,
            carbsPer100g: entry.carbs / factor,
            fatPer100g: entry.fat / factor,
            fiberPer100g: entry.fiber / factor,
            nutritionUnit: selection.unit,
            lastUsedPortion: selection,
          ),
          selection: selection,
          meal: entry.meal,
        ),
      );
    }
    return MealTemplate(
      id: id,
      name: name,
      createdAt: createdAt,
      items: items,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
      };

  factory MealTemplate.fromJson(Map<String, dynamic> json) => MealTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        items: (json['items'] as List<dynamic>? ?? const [])
            .map(
              (item) => MealTemplateItem.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(growable: false),
      );
}
