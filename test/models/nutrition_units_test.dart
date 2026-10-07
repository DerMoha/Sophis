import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/meal_template.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/models/portion_selection.dart';

void main() {
  group('Nutrition units and portions', () {
    test('calculates milliliter selections in the product basis', () {
      const item = FoodItem(
        id: 'water',
        name: 'Water',
        category: 'drink',
        caloriesPer100g: 4,
        proteinPer100g: 0,
        carbsPer100g: 1,
        fatPer100g: 0,
        nutritionUnit: NutritionUnit.milliliter,
      );

      final totals = item.calculateForSelection(
        const PortionSelection(
          amount: 250,
          unit: NutritionUnit.milliliter,
        ),
      );

      expect(totals.calories, 10);
      expect(
        () => item.calculateForSelection(
          const PortionSelection(amount: 250, unit: NutritionUnit.gram),
        ),
        throwsArgumentError,
      );
    });

    test('keeps human labels separate from canonical calculations', () {
      const selection = PortionSelection(
        amount: 80,
        unit: NutritionUnit.gram,
        humanLabel: 'package',
        labelQuantity: 1,
      );

      final restored = PortionSelection.fromJson(selection.toJson());

      expect(restored, equals(selection));
      expect(restored.amount, 80);
      expect(restored.humanLabel, 'package');
    });

    test('does not fabricate portion metadata for legacy entries', () {
      final entry = FoodEntry.fromJson({
        'id': 'legacy-entry',
        'name': 'Oats',
        'calories': 380,
        'protein': 13,
        'carbs': 68,
        'fat': 7,
        'timestamp': '2026-09-04T08:00:00.000Z',
        'meal': 'breakfast',
      });

      expect(entry.portionSelection, isNull);
      expect(entry.toJson().containsKey('portionAmount'), isFalse);
      expect(entry.toJson().containsKey('portionUnit'), isFalse);
    });

    test('scaling a labeled entry updates its displayed amount', () {
      final entry = FoodEntry(
        id: 'entry',
        name: 'Oats (1 package (80g))',
        calories: 304,
        protein: 10.4,
        carbs: 54.4,
        fat: 5.6,
        timestamp: DateTime(2026, 9, 4),
        meal: 'breakfast',
        portionAmount: 80,
        portionUnit: NutritionUnit.gram,
        portionLabel: 'package',
        portionQuantity: 1,
      );

      final scaled = entry.scaledBy(2);

      expect(scaled.portionAmount, 160);
      expect(scaled.portionQuantity, 2);
      expect(scaled.name, 'Oats (2 package (160g))');
      expect(scaled.displayPortionText, '2 package (160g)');
    });

    test('meal templates retain nutrition snapshots and explicit portions', () {
      final entry = FoodEntry(
        id: 'entry',
        name: 'Oats (1 package (80g))',
        calories: 304,
        protein: 10.4,
        carbs: 54.4,
        fat: 5.6,
        timestamp: DateTime(2026, 9, 4),
        meal: 'breakfast',
        sourceFoodId: 'oats-product',
        portionAmount: 80,
        portionUnit: NutritionUnit.gram,
        portionLabel: 'package',
        portionQuantity: 1,
      );

      final template = MealTemplate.fromEntries(
        id: 'template',
        name: 'Usual breakfast',
        createdAt: DateTime(2026, 9, 4),
        entries: [entry],
      );
      final restored = MealTemplate.fromJson(template.toJson());

      expect(restored.items.single.food.id, 'oats-product');
      expect(restored.items.single.food.caloriesPer100g, 380);
      expect(restored.items.single.selection.amount, 80);
      expect(restored.items.single.selection.humanLabel, 'package');
      expect(restored.items.single.meal, 'breakfast');
    });
  });
}
