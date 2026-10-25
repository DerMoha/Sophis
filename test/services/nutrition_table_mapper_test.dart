import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/nutrition_table_mapper.dart';

List<double> _values(NutritionLabelResult label) => [
      label.caloriesPer100g,
      label.proteinPer100g,
      label.carbsPer100g,
      label.fatPer100g,
      label.fiberPer100g,
    ];

void main() {
  group('NutritionTableMapper', () {
    test('took the per-100 column of a two-column table', () {
      final label = NutritionTableMapper.map([
        [
          ['', 'ø/100 ml', 'ø/Portion 250 ml', '% RI'],
          ['Energie', '270 kJ/64 kcal', '680 kJ/162 kcal', '8 %'],
          ['Fett', '1,7 g', '4,3 g', '6 %'],
          ['davon gesättigte Fettsäuren', '0,3 g', '0,8 g', '4 %'],
          ['Kohlenhydrate', '7,2 g', '18,0 g', '7 %'],
          ['davon Zucker', '4,8 g', '12,0 g', '13 %'],
          ['Ballaststoffe', '<0,5 g', '<0,5 g', ''],
          ['Eiweiß', '5,0 g', '12,5 g', '25 %'],
          ['Salz', '0,21 g', '0,53 g', '9 %'],
        ],
      ])!;

      expect(_values(label), [64, 5, 7.2, 1.7, 0.5]);
      expect(label.nutritionUnit, NutritionUnit.milliliter);
      expect(label.servingSizeG, 250);
      expect(label.upperBoundFields, {NutritionLabelField.fiber});
      expect(label.hasRequiredNutrition, isTrue);
    });

    test('joined kJ and kcal printed on two rows', () {
      final label = NutritionTableMapper.map([
        [
          ['Durchschnittliche Nährwerte', 'pro 100g Abtropfgewicht'],
          ['Energie', '399 kJ'],
          ['', '95 kcal'],
          ['Fett', '0,7 g'],
          ['davon gesättigte Fettsäuren', '0 g'],
          ['Kohlenhydrate', '12 g'],
          ['davon Zucker', '0 g'],
          ['Ballaststoffe', '6,5 g'],
          ['Eiweiß', '6,9 g'],
        ],
      ])!;

      expect(_values(label), [95, 6.9, 12, 0.7, 6.5]);
      expect(label.nutritionUnit, NutritionUnit.gram);
    });

    test('read values merged into the label cell and left fiber absent', () {
      final label = NutritionTableMapper.map([
        [
          ['Durchschnittlicher Gehalt in 100 ml:', '%*'],
          ['Energie 197 kJ / 47 kcal', ''],
          ['Fett 0 g', ''],
          ['davon gesättigte Fettsäuren 0 g', ''],
          ['Kohlenhydrate 12 g', ''],
          ['davon Zucker 12 g', ''],
          ['Eiweiß 0 g', ''],
          ['Salz 0,05g', ''],
        ],
      ])!;

      expect(_values(label), [47, 0, 12, 0, 0]);
      expect(label.presentFields.contains(NutritionLabelField.fiber), isFalse);
      expect(label.nutritionUnit, NutritionUnit.milliliter);
    });

    test('read real Vision cells with offset per-100 columns', () {
      // Captured from a curved tub: kcal sits in the label cell, the other
      // per-100 values lead the second column above the portion values.
      final label = NutritionTableMapper.map([
        [
          ['Nährwerte\nø/Portion 125 g\n% RI\n4%', ''],
          ['', '0/100 g |\n331 kJ/78 kcal\n<1%'],
          ['Energie\n262 kJ/62 kcal', '0,3 g\n<1%'],
          ['Fett', '0,2 g\n0,1 g'],
          ['davon gesättigte Fettsäuren', '0,1 g\n5,0 g\n6%\n5,0 g'],
          ['Kohlenhydrate', '4,0 g\n0g'],
          ['davon Zucker', '4,0 g\n13,89\n28.%'],
          ['Ballaststoffe', '0 g\n3%'],
          ['Eiweiß', '11,0 g\n0,16 g'],
          ['Salz', '0,13 g'],
        ],
      ])!;

      expect(_values(label), [62, 11, 4, 0.2, 0]);
      expect(label.servingSizeG, 125);
    });

    test('converted kJ only when no kcal is printed', () {
      final label = NutritionTableMapper.map([
        [
          ['pro 100 g', ''],
          ['Brennwert', '1840 kJ'],
          ['Fett', '14 g'],
        ],
      ])!;
      expect(label.caloriesPer100g, 440);
    });

    test('left a missing row absent instead of guessing', () {
      final label = NutritionTableMapper.map([
        [
          ['', 'ø/100 g'],
          ['Energie', '262 kJ/62 kcal'],
          ['Fett', '0,2 g'],
          ['Eiweiß', '11,0 g'],
        ],
      ])!;
      expect(label.presentFields.contains(NutritionLabelField.carbs), isFalse);
      expect(label.hasRequiredNutrition, isFalse);
    });

    test('returned null for tables without nutrient rows', () {
      expect(
        NutritionTableMapper.map([
          [
            ['Vitamin D', '0,75 µg', '15 %'],
            ['Calcium', '120 mg', '15 %'],
          ],
        ]),
        isNull,
      );
      expect(NutritionTableMapper.map(const []), isNull);
    });
  });
}
