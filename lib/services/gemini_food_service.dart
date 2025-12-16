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

  void dispose() {
    _model = null;
    _isInitialized = false;
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
