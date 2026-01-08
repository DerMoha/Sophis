import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Initialize with API key
  Future<void> initialize(String apiKey) async {
    if (apiKey.isEmpty) {
      throw Exception('API key is required');
    }

    _apiKey = apiKey;
    _model = GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: apiKey,
    );
    _isInitialized = true;
  }

  /// Analyze a single food image
  Future<List<FoodAnalysis>> analyzeFood(File imageFile) async {
    return analyzeFoodMultiple([imageFile]);
  }

  /// Analyze multiple food images with optional correction hint
  Future<List<FoodAnalysis>> analyzeFoodMultiple(
    List<File> imageFiles, {
    String? correctionHint,
  }) async {
    if (!_isInitialized || _model == null) {
      throw Exception('Gemini service not initialized');
    }

    if (imageFiles.isEmpty) {
      return [];
    }

    // Check rate limit
    if (!await canMakeRequest()) {
      throw Exception('Daily limit reached (20 requests/day). Try again tomorrow.');
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

    try {
      final response = await _model!.generateContent([
        Content.multi([prompt, ...imageParts])
      ]);

      // Increment counter after successful request
      await _incrementRequestCount();

      final text = response.text;
      if (text == null || text.isEmpty) {
        return [];
      }

      return _parseResponse(text);
    } catch (e) {
      throw Exception('Failed to analyze image: $e');
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
      return [];
    }
  }

  /// Extract recipe ingredients from an image of a recipe (cookbook, screenshot, etc.)
  Future<RecipeExtraction> extractRecipeFromImage(File imageFile) async {
    if (!_isInitialized || _model == null) {
      throw Exception('Gemini service not initialized');
    }

    // Check rate limit
    if (!await canMakeRequest()) {
      throw Exception('Daily limit reached (20 requests/day). Try again tomorrow.');
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

    try {
      final response = await _model!.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      // Increment counter after successful request
      await _incrementRequestCount();

      final text = response.text;
      if (text == null || text.isEmpty) {
        return RecipeExtraction.empty();
      }

      return _parseRecipeResponse(text);
    } catch (e) {
      throw Exception('Failed to extract recipe: $e');
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

      final ingredients = (json['ingredients'] as List<dynamic>? ?? []).map((i) {
        final ing = i as Map<String, dynamic>;
        return ExtractedIngredient(
          name: ing['name']?.toString() ?? '',
          amount: (ing['amount'] as num?)?.toDouble() ?? 0,
          unit: ing['unit']?.toString() ?? 'g',
          category: ing['category']?.toString() ?? 'other',
        );
      }).where((i) => i.name.isNotEmpty).toList();

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
      return RecipeExtraction.empty();
    }
  }

  void dispose() {
    _model = null;
    _isInitialized = false;
  }
}

/// Result of extracting a recipe from an image
class RecipeExtraction {
  final String? recipeName;
  final int servings;
  final List<ExtractedIngredient> ingredients;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;

  RecipeExtraction({
    required this.recipeName,
    required this.servings,
    required this.ingredients,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
  });

  factory RecipeExtraction.empty() => RecipeExtraction(
        recipeName: null,
        servings: 0,
        ingredients: [],
        totalCalories: 0,
        totalProtein: 0,
        totalCarbs: 0,
        totalFat: 0,
      );

  bool get isEmpty => ingredients.isEmpty;
  bool get isNotEmpty => ingredients.isNotEmpty;

  /// Nutrition per serving
  double get caloriesPerServing => servings > 0 ? totalCalories / servings : 0;
  double get proteinPerServing => servings > 0 ? totalProtein / servings : 0;
  double get carbsPerServing => servings > 0 ? totalCarbs / servings : 0;
  double get fatPerServing => servings > 0 ? totalFat / servings : 0;
}

/// A single ingredient extracted from a recipe image
class ExtractedIngredient {
  final String name;
  final double amount;
  final String unit;
  final String category;

  ExtractedIngredient({
    required this.name,
    required this.amount,
    required this.unit,
    required this.category,
  });

  String get displayAmount {
    if (amount == amount.toInt()) {
      return '${amount.toInt()} $unit';
    }
    return '${amount.toStringAsFixed(1)} $unit';
  }
}

class FoodAnalysis {
  final String name;
  final double portionGrams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  FoodAnalysis({
    required this.name,
    required this.portionGrams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  String get displayName => name;
  String get portionDisplay => '${portionGrams.toStringAsFixed(0)}g';
  String get caloriesDisplay => '${calories.toStringAsFixed(0)} kcal';
  String get macrosDisplay => 
      'P: ${protein.toStringAsFixed(0)}g | C: ${carbs.toStringAsFixed(0)}g | F: ${fat.toStringAsFixed(0)}g';
}
