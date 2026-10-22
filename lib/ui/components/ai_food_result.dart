import 'package:flutter/material.dart';
import 'package:sophis/utils/number_utils.dart';

import 'package:sophis/services/gemini/models/models.dart';

class EditableFoodResult {
  FoodAnalysis originalAnalysis;
  FoodAnalysis currentAnalysis;

  final TextEditingController nameController;
  final TextEditingController portionController;
  final TextEditingController caloriesController;
  final TextEditingController proteinController;
  final TextEditingController carbsController;
  final TextEditingController fatController;
  final TextEditingController fiberController;

  final commentController = TextEditingController();

  bool isAdded = false;
  bool isModified = false;

  EditableFoodResult({required FoodAnalysis analysis})
      : originalAnalysis = analysis,
        currentAnalysis = analysis,
        nameController = TextEditingController(text: analysis.name),
        portionController = TextEditingController(
          text: NumberUtils.format(analysis.portionGrams),
        ),
        caloriesController = TextEditingController(
          text: NumberUtils.formatCalories(analysis.calories),
        ),
        proteinController = TextEditingController(
          text: NumberUtils.formatNutrient(analysis.protein),
        ),
        carbsController = TextEditingController(
          text: NumberUtils.formatNutrient(analysis.carbs),
        ),
        fatController = TextEditingController(
          text: NumberUtils.formatNutrient(analysis.fat),
        ),
        fiberController = TextEditingController(
          text: NumberUtils.formatNutrient(analysis.fiber),
        );

  void dispose() {
    commentController.dispose();
    nameController.dispose();
    portionController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatController.dispose();
    fiberController.dispose();
  }

  TextEditingController get controller => nameController;
  FoodAnalysis get analysis => currentAnalysis;

  FoodAnalysis getEditedAnalysis() {
    return FoodAnalysis(
      name: nameController.text.trim(),
      portionGrams: NumberUtils.parseInput(portionController.text) ??
          currentAnalysis.portionGrams,
      calories: NumberUtils.parseInput(caloriesController.text) ??
          currentAnalysis.calories,
      protein: NumberUtils.parseInput(proteinController.text) ??
          currentAnalysis.protein,
      carbs:
          NumberUtils.parseInput(carbsController.text) ?? currentAnalysis.carbs,
      fat: NumberUtils.parseInput(fatController.text) ?? currentAnalysis.fat,
      fiber:
          NumberUtils.parseInput(fiberController.text) ?? currentAnalysis.fiber,
    );
  }

  String generateCorrectionHint() {
    final hint = StringBuffer('Please re-analyze this food.');
    final original = originalAnalysis;
    final current = getEditedAnalysis();

    if (current.name != original.name) {
      hint.write(' The name should be corrected to "${current.name}".');
    }
    if (current.portionGrams != original.portionGrams) {
      hint.write(
        ' The portion should be ${current.portionGrams.toStringAsFixed(0)}g instead of ${original.portionGrams.toStringAsFixed(0)}g.',
      );
    }
    if (current.calories != original.calories) {
      hint.write(
        ' The calories should be ${current.calories.toStringAsFixed(0)} instead of ${original.calories.toStringAsFixed(0)}.',
      );
    }
    if (current.protein != original.protein) {
      hint.write(
        ' The protein should be ${current.protein.toStringAsFixed(1)}g instead of ${original.protein.toStringAsFixed(1)}g.',
      );
    }
    if (current.carbs != original.carbs) {
      hint.write(
        ' The carbs should be ${current.carbs.toStringAsFixed(1)}g instead of ${original.carbs.toStringAsFixed(1)}g.',
      );
    }
    if (current.fat != original.fat) {
      hint.write(
        ' The fat should be ${current.fat.toStringAsFixed(1)}g instead of ${original.fat.toStringAsFixed(1)}g.',
      );
    }
    if (current.fiber != original.fiber) {
      hint.write(
        ' The fiber should be ${current.fiber.toStringAsFixed(1)}g instead of ${original.fiber.toStringAsFixed(1)}g.',
      );
    }

    return hint.toString();
  }
}

/// Includes every current estimate so comments remain tied to the right item.
String buildFoodReanalysisHint(List<EditableFoodResult> results) {
  final hint = StringBuffer(
    'Re-analyze the entire meal using all user comments below. '
    'Recalculate portion weights and all nutritional values together. '
    'Items without comments still belong to the meal.\n',
  );
  for (var i = 0; i < results.length; i++) {
    final result = results[i];
    final food = result.currentAnalysis;
    hint.writeln(
      'Item ${i + 1}: "${food.name}", ${food.portionGrams}g, '
      '${food.calories} kcal, protein ${food.protein}g, '
      'carbs ${food.carbs}g, fat ${food.fat}g, fiber ${food.fiber}g.',
    );
    final comment = result.commentController.text.trim();
    if (comment.isNotEmpty) hint.writeln('User comment: $comment');
  }
  return hint.toString();
}
