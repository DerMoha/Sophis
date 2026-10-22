import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/label_intake_flow.dart';
import 'package:sophis/services/nutrition_label_parser.dart';
import 'package:sophis/services/nutrition_label_validator.dart';

void main() {
  List<NutritionOcrLine> candidate(String carbs) => [
        // Text-only observations isolate selection policy from spatial parsing.
        const NutritionOcrLine(
          text: 'Nutrition per 100 ml',
          top: 0,
          tokens: [],
        ),
        const NutritionOcrLine(text: 'Energy 64 kcal', top: 20, tokens: []),
        const NutritionOcrLine(text: 'Fat 1.7 g', top: 40, tokens: []),
        NutritionOcrLine(text: 'Carbohydrates $carbs g', top: 60, tokens: []),
        const NutritionOcrLine(text: 'Protein 5 g', top: 80, tokens: []),
        const NutritionOcrLine(text: 'Fiber <0.5 g', top: 100, tokens: []),
      ];

  test('preferred plausible bounded values over repeated missing decimals', () {
    final resolved = LabelIntakeFlow().resolveOcrCandidates([
      candidate('72'),
      candidate('72'),
      candidate('7.2'),
    ]);
    expect(resolved!.label.carbsPer100g, 7.2);
    expect(resolved.label.upperBoundFields, {NutritionLabelField.fiber});
    expect(resolved.validation.isHighConfidence, isFalse);
    expect(
      resolved.validation.issues,
      contains(NutritionLabelIssue.candidateDisagreement),
    );
  });

  test('preferred an observed unit over repeated unitless digit readings', () {
    List<NutritionOcrLine> reading(String protein) => [
          const NutritionOcrLine(
            text: 'Nutrition per 100 g',
            top: 0,
            tokens: [],
          ),
          const NutritionOcrLine(text: 'Energy 70 kcal', top: 20, tokens: []),
          const NutritionOcrLine(text: 'Fat 3.5 g', top: 40, tokens: []),
          const NutritionOcrLine(
            text: 'Carbohydrates 5.2 g',
            top: 60,
            tokens: [],
          ),
          NutritionOcrLine(text: 'Protein $protein', top: 80, tokens: []),
          const NutritionOcrLine(text: 'Fiber 0 g', top: 100, tokens: []),
        ];
    final resolved = LabelIntakeFlow().resolveOcrCandidates([
      reading('4.59'),
      reading('4.59'),
      reading('4.5 g'),
    ]);
    expect(resolved!.label.proteinPer100g, 4.5);
    expect(resolved.validation.isHighConfidence, isFalse);
  });

  test(
      'never invented a missing decimal when every reading disagreed with energy',
      () {
    final resolved = LabelIntakeFlow().resolveOcrCandidates([candidate('72')]);
    expect(resolved!.label.carbsPer100g, 72);
    expect(resolved.validation.isHighConfidence, isFalse);
    expect(
      resolved.validation.issues,
      contains(NutritionLabelIssue.calorieMacroMismatch),
    );
  });

  test('required review for repeated plausible values without gram units', () {
    final unitless = [
      const NutritionOcrLine(text: 'Nutrition per 100 g', top: 0, tokens: []),
      const NutritionOcrLine(text: 'Energy 70 kcal', top: 20, tokens: []),
      const NutritionOcrLine(text: 'Fat 3.59', top: 40, tokens: []),
      const NutritionOcrLine(text: 'Carbohydrates 5.29', top: 60, tokens: []),
      const NutritionOcrLine(text: 'Protein 4.59', top: 80, tokens: []),
    ];
    final resolved =
        LabelIntakeFlow().resolveOcrCandidates([unitless, unitless]);
    expect(resolved!.label.proteinPer100g, 4.59);
    expect(resolved.validation.isUsable, isTrue);
    expect(resolved.validation.isHighConfidence, isFalse);
    expect(
      resolved.validation.issues,
      contains(NutritionLabelIssue.missingUnitEvidence),
    );
  });
}
