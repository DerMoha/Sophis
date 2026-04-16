import 'package:flutter/material.dart';

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

  bool isAdded = false;
  bool isModified = false;

  EditableFoodResult({required FoodAnalysis analysis})
      : originalAnalysis = analysis,
        currentAnalysis = analysis,
        nameController = TextEditingController(text: analysis.name),
        portionController = TextEditingController(
          text: analysis.portionGrams.toStringAsFixed(0),
        ),
        caloriesController =
            TextEditingController(text: analysis.calories.toStringAsFixed(0)),
        proteinController =
            TextEditingController(text: analysis.protein.toStringAsFixed(1)),
        carbsController =
            TextEditingController(text: analysis.carbs.toStringAsFixed(1)),
        fatController =
            TextEditingController(text: analysis.fat.toStringAsFixed(1));

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
      parts.add('portion should be ${portion.toStringAsFixed(0)}g');
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
