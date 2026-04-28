import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sophis/services/gemini/models/models.dart';
import 'package:sophis/services/service_result.dart';

/// Gemini AI service for accurate food recognition and nutrition estimation
class GeminiFoodService {
  GenerativeModel? _model;
  String? _apiKey;
  bool _isInitialized = false;

  // Rate limits for gemini-2.5-flash-lite
  static const int dailyLimit = 20;
  static const String _requestCountKey = 'gemini_request_count';
  static const String _requestDateKey = 'gemini_request_date';

  bool get isInitialized => _isInitialized;
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  /// Get today's request count
  static Future<int> getRequestsToday() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_requestDateKey);
    final today = _getTodayString();

    if (savedDate != today) {
      // New day, reset counter
      return 0;
    }

    return prefs.getInt(_requestCountKey) ?? 0;
  }

  /// Get remaining requests today
  static Future<int> getRemainingRequests() async {
    final used = await getRequestsToday();
    return (dailyLimit - used).clamp(0, dailyLimit);
  }

  /// Check if we can make a request
  static Future<bool> canMakeRequest() async {
    final remaining = await getRemainingRequests();
    return remaining > 0;
  }

  static String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<void> _incrementRequestCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayString();
    final savedDate = prefs.getString(_requestDateKey);

    int count = 0;
    if (savedDate == today) {
      count = prefs.getInt(_requestCountKey) ?? 0;
    }

    await prefs.setString(_requestDateKey, today);
    await prefs.setInt(_requestCountKey, count + 1);
  }

  Future<void> _decrementRequestCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayString();
    final savedDate = prefs.getString(_requestDateKey);

    if (savedDate == today) {
      final count = prefs.getInt(_requestCountKey) ?? 0;
      if (count > 0) {
        await prefs.setInt(_requestCountKey, count - 1);
      }
    }
  }

  /// Initialize with API key
  ServiceResult<void> initialize(String apiKey) {
    if (apiKey.isEmpty) {
      return const Failure(ServiceErrorType.authFailed, 'API key is required');
    }

    _apiKey = apiKey;
    _model = GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: apiKey,
    );
    _isInitialized = true;
    return const Success(null);
  }

  /// Analyze a single food image
  Future<ServiceResult<List<FoodAnalysis>>> analyzeFood(File imageFile) async {
    return analyzeFoodMultiple([imageFile]);
  }

  /// Analyze multiple food images with optional correction hint
  Future<ServiceResult<List<FoodAnalysis>>> analyzeFoodMultiple(
    List<File> imageFiles, {
    String? correctionHint,
  }) async {
    if (!_isInitialized || _model == null) {
      return const Failure(
        ServiceErrorType.unknown,
        'Gemini service not initialized',
      );
    }

    if (imageFiles.isEmpty) {
      return const Success([]);
    }

    // Check rate limit
    if (!await canMakeRequest()) {
      return const Failure(
        ServiceErrorType.rateLimited,
        'Daily limit reached (20 requests/day). Try again tomorrow.',
      );
    }

    // Build image parts
    final imageParts = <DataPart>[];
    for (final file in imageFiles) {
      final bytes = await file.readAsBytes();
      imageParts.add(DataPart('image/jpeg', bytes));
    }

    // Build prompt
    var promptText = '''
Analyze these food images and identify all food items visible.
For each food item, provide:
1. Name of the food (be specific, e.g., "Pepperoni Pizza" not just "Pizza")
2. Estimated portion size in grams
3. Estimated calories
4. Estimated protein in grams
5. Estimated carbs in grams
6. Estimated fat in grams
''';

    if (correctionHint != null && correctionHint.isNotEmpty) {
      promptText += '\n\nIMPORTANT CORRECTION: $correctionHint\n';
    }

    promptText += '''

Respond ONLY with valid JSON in this exact format, no other text:
{
  "foods": [
    {
      "name": "food name",
      "portion_grams": 100,
      "calories": 200,
      "protein": 10,
      "carbs": 20,
      "fat": 8
    }
  ]
}

If no food is visible, return: {"foods": []}
''';

    final prompt = TextPart(promptText);

    // Increment counter before API call to prevent quota leak on failure
    await _incrementRequestCount();

    try {
      final response = await _model!.generateContent([
        Content.multi([prompt, ...imageParts]),
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) {
        return const Success([]);
      }

      final results = _parseResponse(text);
      return Success(results);
    } catch (e) {
      await _decrementRequestCount();
      debugPrint('Gemini food analysis failed: $e');
      return Failure(ServiceErrorType.unknown, 'Failed to analyze image: $e');
    }
  }

  /// Re-analyze a single food item while keeping other items unchanged
  Future<ServiceResult<FoodAnalysis?>> reanalyzeSingleFood(
    List<File> imageFiles, {
    required FoodAnalysis currentFood,
    required String correctionHint,
    List<FoodAnalysis> confirmedFoods = const [],
  }) async {
    if (!_isInitialized || _model == null) {
      return const Failure(
        ServiceErrorType.unknown,
        'Gemini service not initialized',
      );
    }

    if (imageFiles.isEmpty) {
      return const Success(null);
    }

    // Check rate limit
    if (!await canMakeRequest()) {
      return const Failure(
        ServiceErrorType.rateLimited,
        'Daily limit reached (20 requests/day). Try again tomorrow.',
      );
    }

    // Build image parts
    final imageParts = <DataPart>[];
    for (final file in imageFiles) {
      final bytes = await file.readAsBytes();
      imageParts.add(DataPart('image/jpeg', bytes));
    }

    final confirmedList = confirmedFoods.isEmpty
        ? 'None'
        : confirmedFoods.map((food) {
            return '- ${food.name} (${food.portionGrams.toStringAsFixed(0)}g, '
                '${food.calories.toStringAsFixed(0)} kcal, '
                'P ${food.protein.toStringAsFixed(1)}g, '
                'C ${food.carbs.toStringAsFixed(1)}g, '
                'F ${food.fat.toStringAsFixed(1)}g)';
          }).join('\n');

    // Build prompt
    final promptText = '''
You are re-evaluating a single food item in these images.

Confirmed correct foods (do NOT return these):
$confirmedList

Food to correct:
- Name: ${currentFood.name}
- Portion: ${currentFood.portionGrams.toStringAsFixed(0)} g
- Calories: ${currentFood.calories.toStringAsFixed(0)}
- Protein: ${currentFood.protein.toStringAsFixed(1)}
- Carbs: ${currentFood.carbs.toStringAsFixed(1)}
- Fat: ${currentFood.fat.toStringAsFixed(1)}

Correction from user: $correctionHint

Return ONLY the corrected version of the single food item in the JSON format below.
Do NOT include confirmed foods.
If you cannot identify the target item, return {"foods": []}.

Respond ONLY with valid JSON in this exact format, no other text:
{
  "foods": [
    {
      "name": "food name",
      "portion_grams": 100,
      "calories": 200,
      "protein": 10,
      "carbs": 20,
      "fat": 8
    }
  ]
}
''';

    final prompt = TextPart(promptText);

    // Increment counter before API call to prevent quota leak on failure
    await _incrementRequestCount();

    try {
      final response = await _model!.generateContent([
        Content.multi([prompt, ...imageParts]),
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) {
        return const Success(null);
      }

      final results = _parseResponse(text);
      if (results.isEmpty) return const Success(null);
      return Success(results.first);
    } catch (e) {
      await _decrementRequestCount();
      debugPrint('Gemini re-analysis failed: $e');
      return Failure(ServiceErrorType.unknown, 'Failed to re-analyze image: $e');
    }
  }

  List<FoodAnalysis> _parseResponse(String text) {
    try {
      var cleaned = text.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final foods = json['foods'] as List<dynamic>? ?? [];

      return foods.map((f) {
        final food = f as Map<String, dynamic>;
        return FoodAnalysis(
          name: food['name']?.toString() ?? 'Unknown food',
          portionGrams: (food['portion_grams'] as num?)?.toDouble() ?? 100,
          calories: (food['calories'] as num?)?.toDouble() ?? 0,
          protein: (food['protein'] as num?)?.toDouble() ?? 0,
          carbs: (food['carbs'] as num?)?.toDouble() ?? 0,
          fat: (food['fat'] as num?)?.toDouble() ?? 0,
        );
      }).toList();
    } catch (e) {
      debugPrint('Failed to parse Gemini food response: $e');
      return [];
    }
  }

  /// Analyze a nutrition label photo and extract per-100g values
  Future<ServiceResult<NutritionLabelResult?>> analyzeNutritionLabel(
    File imageFile,
  ) async {
    if (!_isInitialized || _model == null) {
      return const Failure(
        ServiceErrorType.unknown,
        'Gemini service not initialized',
      );
    }

    if (!await canMakeRequest()) {
      return const Failure(
        ServiceErrorType.rateLimited,
        'Daily limit reached (20 requests/day). Try again tomorrow.',
      );
    }

    final bytes = await imageFile.readAsBytes();
    final imagePart = DataPart('image/jpeg', bytes);

    const promptText = '''
Analyze this photo of a nutrition label (Nährwerttabelle / Nährwertangaben).
Extract the per-100g values. The label may be in German or English.

Look for:
- Energie / Energy → convert to kcal (1 kJ = 0.239 kcal)
- Eiweiß / Protein
- Kohlenhydrate / Carbohydrates
- Fett / Fat
- Product name if visible on the packaging

Respond ONLY with valid JSON in this exact format, no other text:
{
  "product_name": "Product Name or null if not visible",
  "brand": "Brand or null if not visible",
  "calories_per_100g": 200,
  "protein_per_100g": 10.0,
  "carbs_per_100g": 25.0,
  "fat_per_100g": 8.0,
  "serving_size_g": 30,
  "serving_name": "1 Portion"
}

If the image is not a nutrition label or values are unreadable, return:
{"product_name": null, "brand": null, "calories_per_100g": 0, "protein_per_100g": 0, "carbs_per_100g": 0, "fat_per_100g": 0, "serving_size_g": null, "serving_name": null}
''';

    final prompt = TextPart(promptText);

    // Increment counter before API call to prevent quota leak on failure
    await _incrementRequestCount();

    try {
      final response = await _model!.generateContent([
        Content.multi([prompt, imagePart]),
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) return const Success(null);

      return Success(_parseNutritionLabelResponse(text));
    } catch (e) {
      await _decrementRequestCount();
      debugPrint('Gemini nutrition label analysis failed: $e');
      return Failure(
        ServiceErrorType.unknown,
        'Failed to analyze nutrition label: $e',
      );
    }
  }

  NutritionLabelResult? _parseNutritionLabelResponse(String text) {
    try {
      var cleaned = text.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      final calories = (json['calories_per_100g'] as num?)?.toDouble() ?? 0;
      if (calories == 0) return null;

      return NutritionLabelResult(
        productName: json['product_name']?.toString(),
        brand: json['brand']?.toString(),
        caloriesPer100g: calories,
        proteinPer100g: (json['protein_per_100g'] as num?)?.toDouble() ?? 0,
        carbsPer100g: (json['carbs_per_100g'] as num?)?.toDouble() ?? 0,
        fatPer100g: (json['fat_per_100g'] as num?)?.toDouble() ?? 0,
        servingSizeG: (json['serving_size_g'] as num?)?.toDouble(),
        servingName: json['serving_name']?.toString(),
      );
    } catch (e) {
      debugPrint('Failed to parse nutrition label response: $e');
      return null;
    }
  }

  /// Extract recipe ingredients from an image of a recipe (cookbook, screenshot, etc.)
  Future<ServiceResult<RecipeExtraction>> extractRecipeFromImage(
    File imageFile,
  ) async {
    if (!_isInitialized || _model == null) {
      return const Failure(
        ServiceErrorType.unknown,
        'Gemini service not initialized',
      );
    }

    // Check rate limit
    if (!await canMakeRequest()) {
      return const Failure(
        ServiceErrorType.rateLimited,
        'Daily limit reached (20 requests/day). Try again tomorrow.',
      );
    }

    final bytes = await imageFile.readAsBytes();
    final imagePart = DataPart('image/jpeg', bytes);

    const promptText = '''
Analyze this image of a recipe and extract the following information.
This could be a photo of a cookbook page, a screenshot, a handwritten recipe, or a printed recipe.

Extract:
1. Recipe name (if visible, otherwise suggest a name based on ingredients)
2. Number of servings (if visible, otherwise estimate based on quantities)
3. All ingredients with:
   - Name of ingredient
   - Amount (numeric)
   - Unit (g, ml, cups, tbsp, pieces, etc.)
   - Category for shopping (produce, dairy, protein, grains, pantry, frozen, beverages, other)
4. Estimated total nutrition for the entire recipe:
   - Calories
   - Protein (g)
   - Carbs (g)
   - Fat (g)

Respond ONLY with valid JSON in this exact format, no other text:
{
  "recipe_name": "Recipe Name",
  "servings": 4,
  "ingredients": [
    {
      "name": "Chicken breast",
      "amount": 500,
      "unit": "g",
      "category": "protein"
    },
    {
      "name": "Olive oil",
      "amount": 2,
      "unit": "tbsp",
      "category": "pantry"
    }
  ],
  "total_nutrition": {
    "calories": 1200,
    "protein": 80,
    "carbs": 40,
    "fat": 50
  }
}

If no recipe is visible or readable, return:
{
  "recipe_name": null,
  "servings": 0,
  "ingredients": [],
  "total_nutrition": {"calories": 0, "protein": 0, "carbs": 0, "fat": 0}
}
''';

    final prompt = TextPart(promptText);

    // Increment counter before API call to prevent quota leak on failure
    await _incrementRequestCount();

    try {
      final response = await _model!.generateContent([
        Content.multi([prompt, imagePart]),
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) {
        return Success(RecipeExtraction.empty());
      }

      final result = _parseRecipeResponse(text);
      return Success(result);
    } catch (e) {
      await _decrementRequestCount();
      debugPrint('Gemini recipe extraction failed: $e');
      return Failure(ServiceErrorType.unknown, 'Failed to extract recipe: $e');
    }
  }

  RecipeExtraction _parseRecipeResponse(String text) {
    try {
      var cleaned = text.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      final ingredients = (json['ingredients'] as List<dynamic>? ?? [])
          .map((i) {
            final ing = i as Map<String, dynamic>;
            return ExtractedIngredient(
              name: ing['name']?.toString() ?? '',
              amount: (ing['amount'] as num?)?.toDouble() ?? 0,
              unit: ing['unit']?.toString() ?? 'g',
              category: ing['category']?.toString() ?? 'other',
            );
          })
          .where((i) => i.name.isNotEmpty)
          .toList();

      final nutrition = json['total_nutrition'] as Map<String, dynamic>? ?? {};

      return RecipeExtraction(
        recipeName: json['recipe_name']?.toString(),
        servings: (json['servings'] as num?)?.toInt() ?? 1,
        ingredients: ingredients,
        totalCalories: (nutrition['calories'] as num?)?.toDouble() ?? 0,
        totalProtein: (nutrition['protein'] as num?)?.toDouble() ?? 0,
        totalCarbs: (nutrition['carbs'] as num?)?.toDouble() ?? 0,
        totalFat: (nutrition['fat'] as num?)?.toDouble() ?? 0,
      );
    } catch (e) {
      debugPrint('Failed to parse recipe response: $e');
      return RecipeExtraction.empty();
    }
  }

  void dispose() {
    _model = null;
    _isInitialized = false;
  }
}
