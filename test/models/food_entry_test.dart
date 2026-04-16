import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/food_entry.dart';

void main() {
  group('FoodEntry', () {
    test('copyWith creates a new instance with updated fields', () {
      final original = FoodEntry(
        id: 'entry-1',
        name: 'Apple',
        calories: 52,
        protein: 0.3,
        carbs: 14,
        fat: 0.2,
        timestamp: DateTime(2026, 1, 2, 8, 30),
        meal: 'breakfast',
      );

      final updated = original.copyWith(
        calories: 78,
        meal: 'snack',
      );

      expect(updated.id, equals('entry-1'));
      expect(updated.name, equals('Apple'));
      expect(updated.calories, equals(78));
      expect(updated.protein, equals(0.3));
      expect(updated.carbs, equals(14));
      expect(updated.fat, equals(0.2));
      expect(updated.meal, equals('snack'));
      expect(original.meal, equals('breakfast'));
    });

    test('scaledBy scales all macros by factor', () {
      final entry = FoodEntry(
        id: 'entry-1',
        name: 'Apple (100g)',
        calories: 52,
        protein: 0.3,
        carbs: 14,
        fat: 0.2,
        timestamp: DateTime(2026, 1, 2, 8, 30),
        meal: 'breakfast',
      );

      final scaled = entry.scaledBy(1.5);

      expect(scaled.calories, equals(78));
      expect(scaled.protein, closeTo(0.45, 0.0001));
      expect(scaled.carbs, equals(21));
      expect(scaled.fat, closeTo(0.3, 0.0001));
      expect(scaled.name, equals('Apple (100g)'));
    });

    test('scaledBy preserves original instance', () {
      final entry = FoodEntry(
        id: 'entry-1',
        name: 'Apple',
        calories: 52,
        protein: 0.3,
        carbs: 14,
        fat: 0.2,
        timestamp: DateTime(2026, 1, 2, 8, 30),
        meal: 'breakfast',
      );

      entry.scaledBy(2.0);

      expect(entry.calories, equals(52));
    });

    test('toJson serializes all fields', () {
      final timestamp = DateTime(2026, 1, 2, 8, 30);
      final entry = FoodEntry(
        id: 'entry-1',
        name: 'Apple',
        calories: 52,
        protein: 0.3,
        carbs: 14,
        fat: 0.2,
        timestamp: timestamp,
        meal: 'breakfast',
      );

      final json = entry.toJson();

      expect(json['id'], equals('entry-1'));
      expect(json['name'], equals('Apple'));
      expect(json['calories'], equals(52));
      expect(json['protein'], equals(0.3));
      expect(json['carbs'], equals(14));
      expect(json['fat'], equals(0.2));
      expect(json['timestamp'], equals(timestamp.toIso8601String()));
      expect(json['meal'], equals('breakfast'));
    });

    test('fromJson deserializes all fields', () {
      final json = {
        'id': 'entry-1',
        'name': 'Apple',
        'calories': 52,
        'protein': 0.3,
        'carbs': 14,
        'fat': 0.2,
        'timestamp': '2026-01-02T08:30:00.000',
        'meal': 'breakfast',
      };

      final entry = FoodEntry.fromJson(json);

      expect(entry.id, equals('entry-1'));
      expect(entry.name, equals('Apple'));
      expect(entry.calories, equals(52));
      expect(entry.protein, equals(0.3));
      expect(entry.carbs, equals(14));
      expect(entry.fat, equals(0.2));
      expect(entry.timestamp, equals(DateTime(2026, 1, 2, 8, 30)));
      expect(entry.meal, equals('breakfast'));
    });

    test('fromJson defaults meal to snack when missing', () {
      final json = {
        'id': 'entry-1',
        'name': 'Apple',
        'calories': 52,
        'protein': 0.3,
        'carbs': 14,
        'fat': 0.2,
        'timestamp': '2026-01-02T08:30:00.000',
      };

      final entry = FoodEntry.fromJson(json);

      expect(entry.meal, equals('snack'));
    });

    test('fromJson handles int calories', () {
      final json = {
        'id': 'entry-1',
        'name': 'Apple',
        'calories': 52,
        'protein': 0,
        'carbs': 14,
        'fat': 0.2,
        'timestamp': '2026-01-02T08:30:00.000',
        'meal': 'breakfast',
      };

      final entry = FoodEntry.fromJson(json);

      expect(entry.calories, isA<double>());
      expect(entry.calories, equals(52.0));
    });

    test('json roundtrip preserves all data', () {
      final original = FoodEntry(
        id: 'entry-1',
        name: 'Greek Yogurt',
        calories: 97,
        protein: 9,
        carbs: 4,
        fat: 5,
        timestamp: DateTime(2026, 3, 15, 12, 45),
        meal: 'lunch',
      );

      final json = original.toJson();
      final restored = FoodEntry.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.calories, equals(original.calories));
      expect(restored.protein, equals(original.protein));
      expect(restored.carbs, equals(original.carbs));
      expect(restored.fat, equals(original.fat));
      expect(restored.timestamp, equals(original.timestamp));
      expect(restored.meal, equals(original.meal));
    });
  });
}
