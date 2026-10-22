import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/services/nutrition_label_parser.dart';
import 'package:sophis/services/label_intake_flow.dart';
import 'package:sophis/services/nutrition_label_validator.dart';

List<NutritionOcrLine> readLines(
  Map<String, dynamic> fixture, {
  double scale = 1,
}) =>
    (fixture['lines'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(
          (line) => NutritionOcrLine(
            text: line['text'] as String,
            top: (line['top'] as num).toDouble() * scale,
            height:
                ((line['bottom'] as num) - (line['top'] as num)).toDouble() *
                    scale,
            tokens: (line['tokens'] as List<dynamic>)
                .cast<Map<String, dynamic>>()
                .map(
                  (token) => NutritionOcrToken(
                    text: token['text'] as String,
                    centerX: (token['centerX'] as num).toDouble() * scale,
                    centerY: (token['centerY'] as num).toDouble() * scale,
                  ),
                )
                .toList(),
          ),
        )
        .toList();

void main() {
  final fixtures = (jsonDecode(
    File('test/fixtures/nutrition_labels/curved_two_column_ocr.json')
        .readAsStringSync(),
  ) as List<dynamic>)
      .cast<Map<String, dynamic>>();
  for (final fixture in fixtures) {
    test('parsed captured layout ${fixture['id']}', () {
      final result = NutritionLabelParser.parseLayout(readLines(fixture));
      if (fixture['id'] == 'straight_original' ||
          fixture['id'] == 'angled_enhanced-centered') {
        expect(result, isNotNull);
        expect(result!.caloriesPer100g, 62);
        expect(result.proteinPer100g, 11);
        expect(result.carbsPer100g, 4);
        expect(result.fatPer100g, 0.2);
        expect(result.fiberPer100g, 0);
        expect(result.servingSizeG, 125);
      } else if (fixture['id'] == 'straight_enhanced-centered') {
        // Native OCR read the printed g as a trailing 9. The pipeline must
        // keep disagreement with the original visible, not average it away.
        expect(result!.fatPer100g, 0.29);
      } else if (result != null &&
          NutritionLabelValidator.validate(result).isHighConfidence) {
        expect(result.caloriesPer100g, 62);
        expect(result.proteinPer100g, 11);
        expect(result.carbsPer100g, 4);
        expect(result.fatPer100g, 0.2);
      }
    });
  }
  for (final photo in ['straight', 'angled']) {
    test('selected printed values and reported candidate agreement for $photo',
        () {
      final flow = LabelIntakeFlow();
      final candidates = fixtures
          .where((fixture) => (fixture['id'] as String).startsWith(photo))
          .map(readLines)
          .toList();
      final result = flow.resolveOcrCandidates(candidates);
      expect(result, isNotNull);
      expect(result!.label.caloriesPer100g, 62);
      expect(result.label.proteinPer100g, 11);
      expect(result.label.carbsPer100g, 4);
      expect(result.label.fatPer100g, 0.2);
      // One-edit nutrient-name recovery resolves the angled fiber labels.
      // Straight captures still disagree on the numeric fat value.
      expect(result.validation.isHighConfidence, photo == 'angled');
    });
  }
  final angled = fixtures
      .firstWhere((fixture) => fixture['id'] == 'angled_enhanced-centered');
  for (final scale in [0.5, 2.0]) {
    test('kept row alignment at scale $scale with reversed OCR block order',
        () {
      final result = NutritionLabelParser.parseLayout(
        readLines(angled, scale: scale).reversed.toList(),
      );
      expect(result!.caloriesPer100g, 62);
      expect(result.proteinPer100g, 11);
      expect(result.carbsPer100g, 4);
      expect(result.fatPer100g, 0.2);
    });
  }
  test('left missing fat blank instead of borrowing the saturated fat row', () {
    final lines = readLines(angled)
      ..removeWhere((line) => line.text == '0,2 g');
    final result = NutritionLabelParser.parseLayout(lines);
    expect(result, isNotNull);
    expect(result!.hasRequiredNutrition, isFalse);
    expect(NutritionLabelValidator.validate(result).isHighConfidence, isFalse);
  });
}
