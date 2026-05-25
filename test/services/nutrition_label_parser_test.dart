import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/services/nutrition_label_parser.dart';

void main() {
  group('NutritionLabelParser', () {
    test('parses a standard German nutrition label', () {
      const text = '''
Nährwertangaben pro 100g:
Brennwert 2000 kJ / 480 kcal
Fett 20 g
davon gesättigte Fettsäuren 5 g
Kohlenhydrate 50 g
davon Zucker 30 g
Ballaststoffe 5 g
Eiweiß 10 g
''';

      final result = NutritionLabelParser.parse(text);

      expect(result, isNotNull);
      expect(result!.caloriesPer100g, 480);
      expect(result.proteinPer100g, 10);
      expect(result.carbsPer100g, 50);
      expect(result.fatPer100g, 20);
      expect(result.fiberPer100g, 5);
    });

    test('parses an English nutrition label and scales per-serving to per-100g', () {
      const text = '''
Nutrition Facts
Serving Size 1 cup (240g)
Amount Per Serving
Calories 280
Total Fat 12g
Saturated Fat 4g
Cholesterol 45mg
Sodium 320mg
Total Carbohydrate 35g
Dietary Fiber 3g
Sugars 8g
Protein 8g
''';

      final result = NutritionLabelParser.parse(text);

      expect(result, isNotNull);
      expect(result!.servingSizeG, 240);
      expect(result.caloriesPer100g, closeTo(116.7, 0.1));
      expect(result.proteinPer100g, closeTo(3.33, 0.1));
      expect(result.carbsPer100g, closeTo(14.58, 0.1));
      expect(result.fatPer100g, closeTo(5.0, 0.1));
      expect(result.fiberPer100g, closeTo(1.25, 0.1));
    });

    test('handles kJ-only labels (no kcal)', () {
      const text = '''
Nährwerte pro 100 g
Energie: 2000 kJ
Fett: 20 g
Kohlenhydrate: 50 g
Eiweiß: 10 g
Ballaststoffe: 5 g
''';

      final result = NutritionLabelParser.parse(text);

      expect(result, isNotNull);
      expect(result!.caloriesPer100g, closeTo(478, 1));
    });

    test('scales per-serving values to per-100g', () {
      const text = '''
Nutrition Facts
Serving Size 1 bar (55g)
Amount Per Serving
Calories 230
Total Fat 11g
Total Carbohydrate 29g
Fiber 2g
Protein 6g
''';

      final result = NutritionLabelParser.parse(text);

      expect(result, isNotNull);
      expect(result!.servingSizeG, 55);
      expect(result.caloriesPer100g, closeTo(418.18, 0.1));
      expect(result.proteinPer100g, closeTo(10.91, 0.1));
    });

    test('returns null for non-nutrition text', () {
      const text = 'Hello world this is a test';

      final result = NutritionLabelParser.parse(text);

      expect(result, isNull);
    });

    test('returns null when fewer than 3 fields found', () {
      const text = '''
Nährwertangaben
Energie: 500 kcal
''';

      final result = NutritionLabelParser.parse(text);

      expect(result, isNull);
    });

    test('handles comma as decimal separator', () {
      const text = '''
Nährwerte pro 100 g
Energie: 390 kcal
Fett: 12,5 g
Kohlenhydrate: 45,8 g
Eiweiß: 8,2 g
Ballaststoffe: 3,1 g
''';

      final result = NutritionLabelParser.parse(text);

      expect(result, isNotNull);
      expect(result!.fatPer100g, 12.5);
      expect(result.carbsPer100g, 45.8);
      expect(result.proteinPer100g, 8.2);
      expect(result.fiberPer100g, 3.1);
    });

    test('handles values adjacent to units (no space)', () {
      const text = '''
Pro 100g:
Energie 480kcal
Fett 20g
Kohlenhydrate 50g
Eiweiß 10g
Ballaststoffe 5g
''';

      final result = NutritionLabelParser.parse(text);

      expect(result, isNotNull);
      expect(result!.caloriesPer100g, 480);
      expect(result.fatPer100g, 20);
      expect(result.carbsPer100g, 50);
    });

    test('handles French/European colon notation', () {
      const text = '''
Valeurs nutritionnelles pour 100 g:
Energie: 390 kcal
Matières grasses: 12 g
Glucides: 45 g
Protéines: 8 g
Fibres: 3 g
''';

      final result = NutritionLabelParser.parse(text);

      expect(result, isNotNull);
      expect(result!.caloriesPer100g, closeTo(390, 0));
      expect(result.fatPer100g, 12);
      expect(result.carbsPer100g, 45);
      expect(result.proteinPer100g, 8);
    });

    test('extracts product name from early text lines', () {
      const text = '''
Kölln Haferflocken
Nährwertangaben pro 100g:
Brennwert 1500 kJ / 360 kcal
Fett 7 g
Kohlenhydrate 60 g
Eiweiß 13 g
Ballaststoffe 10 g
''';

      final result = NutritionLabelParser.parse(text);

      expect(result, isNotNull);
      expect(result!.productName, contains('Kölln'));
    });
  });
}
