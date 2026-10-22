import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/nutrition_label_draft.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/label_intake_flow.dart';
import 'package:sophis/services/nutrition_label_parser.dart';

void main() {
  final fixtures = (jsonDecode(
    File(
      'test/fixtures/nutrition_labels/vision_photo_ocr.json',
    ).readAsStringSync(),
  ) as List)
      .cast<Map<String, dynamic>>();
  final originals = {
    'tub_angled': [62.0, 11.0, 4.0, 0.2, 0.0],
    'tub_straight': [62.0, 11.0, 4.0, 0.2, 0.0],
    'soy': [64.0, 5.0, 7.2, 1.7, 0.5],
    'soy_glare': [64.0, 5.0, 7.2, 1.7, 0.5],
    'yogurt': [70.0, 4.5, 5.2, 3.5, 0.0],
    'beans': [95.0, 6.9, 12.0, 0.7, 6.5],
    'energy_drink': [47.0, 0.0, 12.0, 0.0, 0.0],
  };
  final expected = {
    ...originals,
    for (final entry in originals.entries) '${entry.key}_resized': entry.value,
  };
  for (final entry in expected.entries) {
    final photo = entry.key.replaceAll('_resized', '');
    test('resolved captured Vision candidates for ${entry.key}', () {
      final candidates =
          fixtures.where((f) => f['photo'] == entry.key).map((f) {
        return (f['lines'] as List)
            .cast<Map<String, dynamic>>()
            .map(
              (line) => NutritionOcrLine(
                text: line['text'] as String,
                top: (line['top'] as num).toDouble(),
                height: (line['height'] as num).toDouble(),
                left: (line['left'] as num).toDouble(),
                right: (line['right'] as num).toDouble(),
                tokens: (line['tokens'] as List)
                    .cast<Map<String, dynamic>>()
                    .map(
                      (token) => NutritionOcrToken(
                        text: token['text'] as String,
                        centerX: (token['centerX'] as num).toDouble(),
                        centerY: (token['centerY'] as num).toDouble(),
                      ),
                    )
                    .toList(),
              ),
            )
            .toList();
      }).toList();
      final resolved = LabelIntakeFlow().resolveOcrCandidates(candidates);
      expect(resolved, isNotNull);
      final label = resolved!.label;
      expect(
        [
          label.caloriesPer100g,
          label.proteinPer100g,
          label.carbsPer100g,
          label.fatPer100g,
          label.fiberPer100g,
        ],
        entry.value,
      );
      final isSoy = photo.startsWith('soy');
      expect(
        label.nutritionUnit,
        isSoy || photo == 'energy_drink'
            ? NutritionUnit.milliliter
            : NutritionUnit.gram,
      );
      expect(
        label.presentFields.contains(NutritionLabelField.fiber),
        photo != 'energy_drink',
      );
      expect(
        label.upperBoundFields,
        isSoy ? {NutritionLabelField.fiber} : isEmpty,
      );
      if (isSoy) {
        expect(label.servingSizeG, 250);
        expect(resolved.validation.isHighConfidence, isFalse);
        final roundTrip = NutritionLabelDraft.fromJson(
          NutritionLabelDraft.fromResult(label).toJson(),
        ).toResult()!;
        expect(roundTrip.upperBoundFields, {NutritionLabelField.fiber});
      }
      if (entry.key.startsWith('tub') && !entry.key.endsWith('_resized')) {
        expect(resolved.validation.isHighConfidence, isFalse);
      }
    });
  }
}
