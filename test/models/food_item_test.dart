import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/serving_size.dart';

void main() {
  group('FoodItem', () {
    const item = FoodItem(
      id: 'apple-1',
      name: 'Apple',
      category: 'fruit',
      caloriesPer100g: 52,
      proteinPer100g: 0.3,
      carbsPer100g: 14,
      fatPer100g: 0.2,
      brand: 'Farm Fresh',
    );

    test('copyWith creates a new instance with updated fields', () {
      final updated = item.copyWith(
        brand: 'Organic Co',
        caloriesPer100g: 55,
      );

      expect(updated.id, equals('apple-1'));
      expect(updated.name, equals('Apple'));
      expect(updated.brand, equals('Organic Co'));
      expect(updated.caloriesPer100g, equals(55));
      expect(item.brand, equals('Farm Fresh'));
    });

    test('calculateFor returns correct nutrition for given grams', () {
      final nutrition = item.calculateFor(150);

      expect(nutrition.calories, equals(78));
      expect(nutrition.protein, closeTo(0.45, 0.001));
      expect(nutrition.carbs, equals(21));
      expect(nutrition.fat, closeTo(0.3, 0.0001));
    });

    test('calculateFor handles 0 grams', () {
      final nutrition = item.calculateFor(0);

      expect(nutrition.calories, equals(0));
      expect(nutrition.protein, equals(0));
      expect(nutrition.carbs, equals(0));
      expect(nutrition.fat, equals(0));
    });

    test('calculateFor handles 100 grams', () {
      final nutrition = item.calculateFor(100);

      expect(nutrition.calories, equals(52));
      expect(nutrition.protein, closeTo(0.3, 0.0001));
      expect(nutrition.carbs, equals(14));
      expect(nutrition.fat, equals(0.2));
    });

    test('calculateFor handles fractional grams', () {
      final nutrition = item.calculateFor(50.5);

      expect(nutrition.calories, closeTo(26.26, 0.01));
      expect(nutrition.protein, closeTo(0.1515, 0.001));
    });

    test('toJson serializes all fields', () {
      final json = item.toJson();

      expect(json['id'], equals('apple-1'));
      expect(json['name'], equals('Apple'));
      expect(json['category'], equals('fruit'));
      expect(json['caloriesPer100g'], equals(52));
      expect(json['proteinPer100g'], equals(0.3));
      expect(json['carbsPer100g'], equals(14));
      expect(json['fatPer100g'], equals(0.2));
      expect(json['brand'], equals('Farm Fresh'));
      expect(json['isFavorite'], isFalse);
    });

    test('toJson includes optional fields when present', () {
      final itemWithOptional = item.copyWith(
        barcode: '123456789',
        imageUrl: 'https://example.com/apple.jpg',
      );

      final json = itemWithOptional.toJson();

      expect(json['barcode'], equals('123456789'));
      expect(json['imageUrl'], equals('https://example.com/apple.jpg'));
    });

    test('fromJson deserializes all required fields', () {
      final json = {
        'id': 'apple-1',
        'name': 'Apple',
        'category': 'fruit',
        'caloriesPer100g': 52.0,
        'proteinPer100g': 0.3,
        'carbsPer100g': 14.0,
        'fatPer100g': 0.2,
      };

      final item = FoodItem.fromJson(json);

      expect(item.id, equals('apple-1'));
      expect(item.name, equals('Apple'));
      expect(item.category, equals('fruit'));
      expect(item.caloriesPer100g, equals(52.0));
      expect(item.proteinPer100g, equals(0.3));
      expect(item.carbsPer100g, equals(14.0));
      expect(item.fatPer100g, equals(0.2));
    });

    test('fromJson handles optional fields', () {
      final json = {
        'id': 'apple-1',
        'name': 'Apple',
        'category': 'fruit',
        'caloriesPer100g': 52.0,
        'proteinPer100g': 0.3,
        'carbsPer100g': 14.0,
        'fatPer100g': 0.2,
        'barcode': '123456789',
        'brand': 'Farm Fresh',
        'imageUrl': 'https://example.com/apple.jpg',
        'isFavorite': true,
      };

      final item = FoodItem.fromJson(json);

      expect(item.barcode, equals('123456789'));
      expect(item.brand, equals('Farm Fresh'));
      expect(item.imageUrl, equals('https://example.com/apple.jpg'));
      expect(item.isFavorite, isTrue);
    });

    test('fromJson defaults isFavorite to false when missing', () {
      final json = {
        'id': 'apple-1',
        'name': 'Apple',
        'category': 'fruit',
        'caloriesPer100g': 52.0,
        'proteinPer100g': 0.3,
        'carbsPer100g': 14.0,
        'fatPer100g': 0.2,
      };

      final item = FoodItem.fromJson(json);

      expect(item.isFavorite, isFalse);
    });

    test('fromJson handles servings list', () {
      final json = {
        'id': 'yogurt-1',
        'name': 'Greek Yogurt',
        'category': 'dairy',
        'caloriesPer100g': 97.0,
        'proteinPer100g': 9.0,
        'carbsPer100g': 4.0,
        'fatPer100g': 5.0,
        'servings': [
          {'name': 'small', 'grams': 125},
          {'name': 'large', 'grams': 250},
        ],
      };

      final item = FoodItem.fromJson(json);

      expect(item.servings.length, equals(2));
      expect(item.servings[0].name, equals('small'));
      expect(item.servings[0].grams, equals(125));
      expect(item.servings[1].name, equals('large'));
      expect(item.servings[1].grams, equals(250));
    });

    test('fromJson defaults servings to empty when missing', () {
      final json = {
        'id': 'apple-1',
        'name': 'Apple',
        'category': 'fruit',
        'caloriesPer100g': 52.0,
        'proteinPer100g': 0.3,
        'carbsPer100g': 14.0,
        'fatPer100g': 0.2,
      };

      final item = FoodItem.fromJson(json);

      expect(item.servings, isEmpty);
    });

    test('json roundtrip preserves all data', () {
      final itemWithAll = item.copyWith(
        barcode: '123456789',
        imageUrl: 'https://example.com/apple.jpg',
        servings: [
          const ServingSize(name: 'small', grams: 100),
          const ServingSize(name: 'large', grams: 200),
        ],
        isFavorite: true,
      );

      final json = itemWithAll.toJson();
      final restored = FoodItem.fromJson(json);

      expect(restored.id, equals(itemWithAll.id));
      expect(restored.name, equals(itemWithAll.name));
      expect(restored.category, equals(itemWithAll.category));
      expect(restored.caloriesPer100g, equals(itemWithAll.caloriesPer100g));
      expect(restored.proteinPer100g, equals(itemWithAll.proteinPer100g));
      expect(restored.carbsPer100g, equals(itemWithAll.carbsPer100g));
      expect(restored.fatPer100g, equals(itemWithAll.fatPer100g));
      expect(restored.barcode, equals(itemWithAll.barcode));
      expect(restored.brand, equals(itemWithAll.brand));
      expect(restored.imageUrl, equals(itemWithAll.imageUrl));
      expect(restored.servings.length, equals(itemWithAll.servings.length));
      expect(restored.isFavorite, equals(itemWithAll.isFavorite));
    });

    test('copyWith preserves unchanged fields', () {
      final updated = item.copyWith(name: 'Green Apple');

      expect(updated.category, equals('fruit'));
      expect(updated.caloriesPer100g, equals(52));
      expect(updated.brand, equals('Farm Fresh'));
    });
  });
}
