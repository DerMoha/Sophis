import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/on_device_label_reader.dart';

void main() {
  group('OnDeviceLabelReader', () {
    const sauce = '''
Energia - Energie - Energy kJ 364
Valor energético - Energija kcal 87
Grassi - Fett - Fat g 5,0
di cui acidi grassi saturi - davon gesättigte Fettsäuren g 1,7
Carboidrati - Kohlenhydrate - Carbohydrate g 6,3
di cui zuccheri - davon Zucker g 4,8
Fibre - Ballaststoffe g 2,0
Proteine - Eiweiß - Protein g 3,3
Sale - Salz g 1,0''';

    test('kept model values that are printed on the label', () {
      final label = OnDeviceLabelReader.fromValues(
        {
          'basis': 'g',
          'calories': 87,
          'fat': 5.0,
          'carbs': 6.3,
          'fiber': 2.0,
          'protein': 3.3,
        },
        sauce,
      )!;

      expect(label.caloriesPer100g, 87);
      expect(label.fatPer100g, 5);
      expect(label.carbsPer100g, 6.3);
      expect(label.fiberPer100g, 2);
      expect(label.proteinPer100g, 3.3);
      expect(label.hasRequiredNutrition, isTrue);
      expect(label.nutritionUnit, NutritionUnit.gram);
    });

    test('dropped numbers the model invented', () {
      final label = OnDeviceLabelReader.fromValues(
        {
          'basis': 'g',
          'calories': 90, // not printed
          'fat': 5.0,
          'carbs': 6.3,
          'protein': 3.3,
          'serving': 125, // not printed
        },
        sauce,
      )!;

      expect(
        label.presentFields.contains(NutritionLabelField.calories),
        isFalse,
      );
      expect(label.hasRequiredNutrition, isFalse);
      expect(label.servingSizeG, isNull);
    });

    test('kept a printed less-than bound as an upper bound', () {
      final label = OnDeviceLabelReader.fromValues(
        {'basis': 'ml', 'fiber': 0.5, 'calories': 64},
        'Energie 270 kJ/64 kcal\nBallaststoffe <0,5 g',
      )!;
      expect(label.upperBoundFields, {NutritionLabelField.fiber});
      expect(label.nutritionUnit, NutritionUnit.milliliter);
    });

    test('ignored bare numbers and fiber the label does not list', () {
      final label = OnDeviceLabelReader.fromValues(
        {'basis': 'g', 'calories': 216, 'protein': 0, 'fiber': 0, 'fat': 0.3},
        'Brennwert kJ/kcal 918/216\nFett 0,3 g\nEiweiß 0,8 g\n'
        'Packung 0800 333 5211',
      )!;
      expect(label.caloriesPer100g, 216);
      expect(label.fatPer100g, 0.3);
      expect(label.presentFields, {
        NutritionLabelField.calories,
        NutritionLabelField.fat,
      });
    });

    test('returned null when nothing survives the check', () {
      expect(
        OnDeviceLabelReader.fromValues({'calories': 120}, 'Fett 3 g'),
        isNull,
      );
    });
  });
}
