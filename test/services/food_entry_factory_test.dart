import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/food_item.dart';
import 'package:sophis/services/food_entry_factory.dart';

void main() {
  group('FoodEntryFactory', () {
    test('builds a food entry from a food item and portion size', () {
      const item = FoodItem(
        id: 'apple',
        name: 'Apple',
        category: 'fruit',
        caloriesPer100g: 52,
        proteinPer100g: 0.3,
        carbsPer100g: 14,
        fatPer100g: 0.2,
        brand: 'Farm Fresh',
      );

      final entry = FoodEntryFactory.fromFoodItem(
        item: item,
        grams: 150,
        meal: 'snack',
        timestamp: DateTime(2026, 1, 2, 8, 30),
        id: 'entry-1',
      );

      expect(entry.id, 'entry-1');
      expect(entry.name, 'Farm Fresh Apple (150g)');
      expect(entry.calories, 78);
      expect(entry.protein, closeTo(0.45, 0.0001));
      expect(entry.carbs, 21);
      expect(entry.fat, closeTo(0.3, 0.0001));
      expect(entry.meal, 'snack');
      expect(entry.timestamp, DateTime(2026, 1, 2, 8, 30));
    });

    test('creates a manual entry with provided fields', () {
      final entry = FoodEntryFactory.create(
        id: 'manual-1',
        name: 'Protein Shake',
        calories: 220,
        protein: 30,
        carbs: 12,
        fat: 5,
        meal: 'breakfast',
        timestamp: DateTime(2026, 1, 3, 7),
      );

      expect(entry.id, 'manual-1');
      expect(entry.name, 'Protein Shake');
      expect(entry.calories, 220);
      expect(entry.protein, 30);
      expect(entry.carbs, 12);
      expect(entry.fat, 5);
      expect(entry.meal, 'breakfast');
      expect(entry.timestamp, DateTime(2026, 1, 3, 7));
    });
  });
}
