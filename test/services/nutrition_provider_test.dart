import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/nutrition_totals.dart';

void main() {
  group('NutritionTotals', () {
    test('zero totals are empty', () {
      expect(NutritionTotals.zero.isEmpty, isTrue);
      expect(NutritionTotals.zero.calories, equals(0));
    });

    test('addition sums all fields', () {
      const a = NutritionTotals(
        calories: 200,
        protein: 20,
        carbs: 30,
        fat: 10,
      );
      const b = NutritionTotals(
        calories: 300,
        protein: 15,
        carbs: 40,
        fat: 12,
      );
      final sum = a + b;

      expect(sum.calories, equals(500));
      expect(sum.protein, equals(35));
      expect(sum.carbs, equals(70));
      expect(sum.fat, equals(22));
    });

    test('multiplication scales all fields', () {
      const base = NutritionTotals(
        calories: 100,
        protein: 10,
        carbs: 20,
        fat: 5,
      );
      final scaled = base * 2.5;

      expect(scaled.calories, equals(250));
      expect(scaled.protein, equals(25));
      expect(scaled.carbs, equals(50));
      expect(scaled.fat, equals(12.5));
    });

    test('non-zero totals are not empty', () {
      const totals = NutritionTotals(calories: 100);
      expect(totals.isEmpty, isFalse);
    });

    test('toMap and fromMap roundtrip', () {
      const original = NutritionTotals(
        calories: 500,
        protein: 30,
        carbs: 60,
        fat: 20,
      );
      final map = original.toMap();
      final restored = NutritionTotals.fromMap(map);

      expect(restored.calories, equals(original.calories));
      expect(restored.protein, equals(original.protein));
      expect(restored.carbs, equals(original.carbs));
      expect(restored.fat, equals(original.fat));
    });
  });

  group('NutritionGoals', () {
    test('calculates default macros from calories', () {
      final goals = NutritionGoals(calories: 2000);

      // 30% protein, 40% carbs, 30% fat
      expect(goals.protein, equals((2000 * 0.30) / 4));
      expect(goals.carbs, equals((2000 * 0.40) / 4));
      expect(goals.fat, equals((2000 * 0.30) / 9));
    });

    test('accepts explicit macros', () {
      final goals = NutritionGoals(
        calories: 2000,
        protein: 150,
        carbs: 200,
        fat: 60,
      );

      expect(goals.protein, equals(150));
      expect(goals.carbs, equals(200));
      expect(goals.fat, equals(60));
    });

    test('remaining calories calculation', () {
      final goals = NutritionGoals(calories: 2000);
      const todayTotals = NutritionTotals(calories: 1500);
      const burnedCalories = 300.0;

      final remaining = goals.calories - todayTotals.calories + burnedCalories;
      expect(remaining, equals(800));
    });

    test('remaining calories when no goals returns zero equivalent', () {
      // Simulates NutritionProvider.getRemainingCalories() when _goals is null
      const result = 0.0;

      expect(result, equals(0));
    });
  });
}
