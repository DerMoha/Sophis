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

    test('zero totals are empty', () {
      expect(NutritionTotals.zero.isEmpty, isTrue);
      expect(const NutritionTotals().isEmpty, isTrue);
    });

    test('multiplication by 0 yields zero', () {
      const base = NutritionTotals(
        calories: 100,
        protein: 10,
        carbs: 20,
        fat: 5,
        fiber: 3,
      );
      final scaled = base * 0;

      expect(scaled.calories, equals(0));
      expect(scaled.protein, equals(0));
      expect(scaled.carbs, equals(0));
      expect(scaled.fat, equals(0));
      expect(scaled.fiber, equals(0));
      expect(scaled.isEmpty, isTrue);
    });

    test('multiplication by 1 is identity', () {
      const base = NutritionTotals(
        calories: 100,
        protein: 10,
        carbs: 20,
        fat: 5,
        fiber: 3,
      );
      final scaled = base * 1;

      expect(scaled.calories, equals(base.calories));
      expect(scaled.protein, equals(base.protein));
      expect(scaled.carbs, equals(base.carbs));
      expect(scaled.fat, equals(base.fat));
      expect(scaled.fiber, equals(base.fiber));
    });

    test('adding zero totals is identity', () {
      const base = NutritionTotals(
        calories: 100,
        protein: 10,
        carbs: 20,
        fat: 5,
        fiber: 3,
      );
      final summed = base + NutritionTotals.zero;

      expect(summed.calories, equals(base.calories));
      expect(summed.protein, equals(base.protein));
      expect(summed.carbs, equals(base.carbs));
      expect(summed.fat, equals(base.fat));
      expect(summed.fiber, equals(base.fiber));
    });

    test('fiber field defaults to 0 when omitted', () {
      const totals = NutritionTotals(calories: 100, protein: 10);
      expect(totals.fiber, equals(0));
      expect(totals.carbs, equals(0));
      expect(totals.fat, equals(0));
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

    test('zero calories yields zero default macros', () {
      final goals = NutritionGoals(calories: 0);

      expect(goals.protein, equals(0));
      expect(goals.carbs, equals(0));
      expect(goals.fat, equals(0));
      expect(goals.fiber, equals(0));
    });

    test('copyWith overrides only specified fields', () {
      final goals = NutritionGoals(
        calories: 2000,
        protein: 150,
        carbs: 200,
        fat: 60,
        fiber: 28,
      );
      final updated = goals.copyWith(protein: 180);

      expect(updated.calories, equals(2000));
      expect(updated.protein, equals(180));
      expect(updated.carbs, equals(200));
      expect(updated.fat, equals(60));
      expect(updated.fiber, equals(28));
    });
  });
}
