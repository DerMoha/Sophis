import 'package:flutter/material.dart';

import 'package:sophis/services/gemini/models/models.dart';
import 'package:sophis/utils/number_utils.dart';

class EditableFoodResult {
  FoodAnalysis originalAnalysis;
  FoodAnalysis currentAnalysis;

  final TextEditingController nameController;
  final TextEditingController portionController;
  final TextEditingController caloriesController;
  final TextEditingController proteinController;
  final TextEditingController carbsController;
  final TextEditingController fatController;

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
        );

  TextEditingController get controller => nameController;
  FoodAnalysis get analysis => currentAnalysis;

  FoodAnalysis getEditedAnalysis() {
    return FoodAnalysis(
      name: nameController.text.trim(),
      portionGrams: double.tryParse(portionController.text) ??
          currentAnalysis.portionGrams,
      calories:
          double.tryParse(caloriesController.text) ?? currentAnalysis.calories,
      protein:
          double.tryParse(proteinController.text) ?? currentAnalysis.protein,
      carbs: double.tryParse(carbsController.text) ?? currentAnalysis.carbs,
      fat: double.tryParse(fatController.text) ?? currentAnalysis.fat,
    );
  }

  String generateCorrectionHint() {
    final parts = <String>[];

    if (nameController.text.trim() != originalAnalysis.name) {
      parts.add('The food is actually "${nameController.text.trim()}"');
    }

    final portion = double.tryParse(portionController.text);
    if (portion != null &&
        (portion - originalAnalysis.portionGrams).abs() > 5) {
      parts.add('portion should be ${NumberUtils.format(portion)}g');
    }

    if (parts.isEmpty) {
      parts.add(
        'Re-evaluate the nutrition values for "${nameController.text.trim()}"',
      );
    }

    return '${parts.join(', ')}.';
  }

  void dispose() {
    nameController.dispose();
    portionController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatController.dispose();
  }
}
