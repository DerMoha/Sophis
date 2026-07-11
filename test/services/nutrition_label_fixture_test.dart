import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/services/nutrition_label_parser.dart';

void main() {
  final manifest = jsonDecode(
    File('test/fixtures/nutrition_labels/manifest.json').readAsStringSync(),
  ) as List<dynamic>;

  for (final fixtureValue in manifest) {
    final fixture = fixtureValue as Map<String, dynamic>;
    test('matches captured label fixture ${fixture['id']}', () {
      final expected = fixture['expected'] as Map<String, dynamic>;
      final result = NutritionLabelParser.parse(fixture['ocr_text'] as String);
      expect(result, isNotNull);
      expect(
        result!.caloriesPer100g,
        closeTo(_number(expected, 'calories'), 0.1),
      );
      expect(result.proteinPer100g, closeTo(_number(expected, 'protein'), 0.1));
      expect(result.carbsPer100g, closeTo(_number(expected, 'carbs'), 0.1));
      expect(result.fatPer100g, closeTo(_number(expected, 'fat'), 0.1));
      expect(result.fiberPer100g, closeTo(_number(expected, 'fiber'), 0.1));
    });
  }
}

double _number(Map<String, dynamic> values, String key) =>
    (values[key] as num).toDouble();
