import 'dart:io';

import 'package:sophis/services/gemini/models/food_analysis.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/gemini/models/recipe_extraction.dart';
import 'package:sophis/services/service_result.dart';

/// Common feature contract used by cloud AI adapters.
abstract interface class AiFoodService {
  String get providerId;
  bool get isInitialized;
  bool get hasApiKey;

  ServiceResult<void> initialize(String apiKey);
  Future<ServiceResult<List<FoodAnalysis>>> analyzeFoodMultiple(
    List<File> imageFiles, {
    String? correctionHint,
  });
  Future<ServiceResult<FoodAnalysis?>> reanalyzeSingleFood(
    List<File> imageFiles, {
    required FoodAnalysis currentFood,
    required String correctionHint,
    List<FoodAnalysis> confirmedFoods,
  });
  Future<ServiceResult<RecipeExtraction>> extractRecipeFromImage(File image);
  Future<ServiceResult<NutritionLabelResult?>> parseNutritionImage(
    File image, {
    String? ocrText,
  });
  Future<ServiceResult<NutritionLabelResult?>> parseNutritionText(String text);
  void dispose();
}
