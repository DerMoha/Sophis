import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/nutrition_label_draft.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';

void main() {
  group('NutritionLabelDraft', () {
    test('keeps incomplete fields nullable and parses localized numbers', () {
      final draft = NutritionLabelDraft.fromJson({
        'caloriesPer100': '1.234,5',
        'proteinPer100': 10,
        'nutritionUnit': 'ml',
        'analysisSource': 'gemini',
      });

      expect(draft.caloriesPer100, 1234.5);
      expect(draft.fatPer100, isNull);
      expect(draft.nutritionUnit.symbol, 'ml');
      expect(draft.analysisSource, NutritionLabelAnalysisSource.gemini);
      expect(draft.toResult(), isNull);
    });

    test('converts a completed draft to a confirmable result', () {
      const draft = NutritionLabelDraft(
        caloriesPer100: 40,
        proteinPer100: 1,
        carbsPer100: 8,
        fatPer100: 0,
      );

      final result = draft.toResult();

      expect(result, isNotNull);
      expect(result!.hasRequiredNutrition, isTrue);
      expect(result.presentFields, contains(NutritionLabelField.fat));
    });
  });
}
