import 'dart:math' as math;

import 'package:sophis/services/gemini/models/nutrition_label_result.dart';

class NutritionLabelValidation {
  final bool isUsable;
  final bool isHighConfidence;
  final List<String> issues;

  const NutritionLabelValidation({
    required this.isUsable,
    required this.isHighConfidence,
    required this.issues,
  });
}

class NutritionLabelValidator {
  static NutritionLabelValidation validate(NutritionLabelResult label) {
    final issues = <String>[];
    final macros = <double>[
      label.proteinPer100g,
      label.carbsPer100g,
      label.fatPer100g,
      label.fiberPer100g,
    ];

    if (!label.caloriesPer100g.isFinite ||
        label.caloriesPer100g <= 0 ||
        label.caloriesPer100g > 950) {
      issues.add('Calories are outside the expected per-100g range');
    }
    if (macros.any((value) => !value.isFinite || value < 0 || value > 100)) {
      issues.add('A nutrient is outside the expected per-100g range');
    }

    final macroTotal = macros.reduce((a, b) => a + b);
    if (macroTotal > 105) {
      issues.add('Nutrient values total more than 100g');
    }

    final estimatedCalories = label.proteinPer100g * 4 +
        label.carbsPer100g * 4 +
        label.fatPer100g * 9 +
        label.fiberPer100g * 2;
    final difference = (estimatedCalories - label.caloriesPer100g).abs();
    final tolerance = math.max(80.0, label.caloriesPer100g * 0.35);
    if (estimatedCalories > 0 && difference > tolerance) {
      issues.add('Calories do not match the detected macronutrients');
    }

    final presentMacros = macros.where((value) => value > 0).length;
    final usable = issues.every(
          (issue) =>
              issue == 'Calories do not match the detected macronutrients',
        ) &&
        label.caloriesPer100g > 0 &&
        label.caloriesPer100g <= 950 &&
        macros.every((value) => value.isFinite && value >= 0 && value <= 100) &&
        macroTotal <= 105 &&
        presentMacros >= 2;

    return NutritionLabelValidation(
      isUsable: usable,
      isHighConfidence: usable && issues.isEmpty && presentMacros >= 3,
      issues: issues,
    );
  }
}
