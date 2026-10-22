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
      'test/fixtures/nutrition_labels/android_paddle_v6_ocr.json',
    ).readAsStringSync(),
  ) as List)
      .cast<Map<String, dynamic>>();
  final originals = {
    '091005': [62.0, 11.0, 4.0, 0.2, 0.0],
    '090958': [62.0, 11.0, 4.0, 0.2, 0.0],
    '171032': [64.0, 5.0, 7.2, 1.7, 0.5],
    '171031': [64.0, 5.0, 7.2, 1.7, 0.5],
    '171019': [70.0, 4.5, 5.2, 3.5, 0.0],
    '171017': [95.0, 6.9, 12.0, 0.7, 6.5],
    '171024': [47.0, 0.0, 12.0, 0.0, 0.0],
  };
  final expected = {
    ...originals,
    for (final entry in originals.entries) '${entry.key}_native': entry.value,
  };
  for (final entry in expected.entries) {
    final photo = entry.key.replaceAll('_native', '');
    test('resolved captured Android Paddle v6 candidates for ${entry.key}', () {
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
      final isSoy = (photo == '171032' || photo == '171031');
      expect(
        label.nutritionUnit,
        isSoy || photo == '171024'
            ? NutritionUnit.milliliter
            : NutritionUnit.gram,
      );
      expect(
        label.presentFields.contains(NutritionLabelField.fiber),
        photo != '171024',
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
      if (photo == '091005') {
        expect(resolved.validation.isHighConfidence, isFalse);
      }
    });
  }
}
