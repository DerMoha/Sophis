import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/nutrition_label_validator.dart';

void main() {
  group('NutritionLabelValidator', () {
    test('keeps a calorie mismatch usable and exposes a typed issue', () {
      const label = NutritionLabelResult(
        caloriesPer100g: 300,
        proteinPer100g: 10,
        carbsPer100g: 10,
        fatPer100g: 10,
      );

      final validation = NutritionLabelValidator.validate(label);

      expect(validation.isUsable, isTrue);
      expect(
        validation.issues,
        contains(NutritionLabelIssue.calorieMacroMismatch),
      );
    });

    test('flags portion calories mixed with per-100g macros', () {
      const label = NutritionLabelResult(
        caloriesPer100g: 78,
        proteinPer100g: 11,
        carbsPer100g: 4,
        fatPer100g: 0.2,
      );
      final validation = NutritionLabelValidator.validate(label);
      expect(validation.isUsable, isTrue);
      expect(validation.isHighConfidence, isFalse);
      expect(
        validation.issues,
        contains(NutritionLabelIssue.calorieMacroMismatch),
      );
      expect(
        NutritionLabelValidator.validate(label.copyWith(caloriesPer100g: 62))
            .isHighConfidence,
        isTrue,
      );
    });

    test('rejects values outside the expected nutrient range', () {
      const label = NutritionLabelResult(
        caloriesPer100g: 200,
        proteinPer100g: 120,
        carbsPer100g: 10,
        fatPer100g: 10,
      );

      final validation = NutritionLabelValidator.validate(label);

      expect(validation.isUsable, isFalse);
      expect(
        validation.issues,
        contains(NutritionLabelIssue.nutrientOutOfRange),
      );
    });

    test('accepts valid products with only one positive macro', () {
      const label = NutritionLabelResult(
        caloriesPer100g: 40,
        proteinPer100g: 0,
        carbsPer100g: 10,
        fatPer100g: 0,
      );

      final validation = NutritionLabelValidator.validate(label);

      expect(validation.isUsable, isTrue);
      expect(validation.isHighConfidence, isTrue);
    });
  });
}
