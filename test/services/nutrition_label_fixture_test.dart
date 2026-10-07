import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/nutrition_label_parser.dart';

void main() {
  final manifest = jsonDecode(
    File('test/fixtures/nutrition_labels/manifest.json').readAsStringSync(),
  ) as List<dynamic>;

  for (final fixtureValue in manifest) {
    final fixture = fixtureValue as Map<String, dynamic>;
    test('matches captured label fixture ${fixture['id']}', () {
      final expected = fixture['expected'] as Map<String, dynamic>;
      final rawLines = fixture['lines'];
      final result = rawLines is List
          ? NutritionLabelParser.parseLayout(
              rawLines
                  .cast<Map<String, dynamic>>()
                  .map(
                    (line) => NutritionOcrLine(
                      text: line['text'] as String,
                      top: (line['top'] as num).toDouble(),
                      tokens: (line['tokens'] as List<dynamic>)
                          .cast<Map<String, dynamic>>()
                          .map(
                            (token) => NutritionOcrToken(
                              text: token['text'] as String,
                              centerX: (token['centerX'] as num).toDouble(),
                            ),
                          )
                          .toList(),
                    ),
                  )
                  .toList(),
            )
          : NutritionLabelParser.parse(fixture['ocr_text'] as String);
      expect(result, isNotNull);
      expect(
        result!.caloriesPer100g,
        closeTo(_number(expected, 'calories'), 0.1),
      );
      expect(result.proteinPer100g, closeTo(_number(expected, 'protein'), 0.1));
      expect(result.carbsPer100g, closeTo(_number(expected, 'carbs'), 0.1));
      expect(result.fatPer100g, closeTo(_number(expected, 'fat'), 0.1));
      expect(result.fiberPer100g, closeTo(_number(expected, 'fiber'), 0.1));
      final expectedUnit = expected['unit'] as String?;
      if (expectedUnit != null) {
        expect(result.nutritionUnit.storageValue, expectedUnit);
      }
      if (expected['fiberPresent'] == false) {
        expect(
          result.presentFields.contains(NutritionLabelField.fiber),
          isFalse,
        );
      }
    });
  }
}

double _number(Map<String, dynamic> values, String key) =>
    (values[key] as num).toDouble();
