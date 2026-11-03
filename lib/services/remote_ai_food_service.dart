import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sophis/models/app_settings.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/services/ai_food_service.dart';
import 'package:sophis/services/gemini/models/extracted_ingredient.dart';
import 'package:sophis/services/gemini/models/food_analysis.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/gemini/models/recipe_extraction.dart';
import 'package:sophis/services/service_result.dart';

/// Adapter for OpenAI, OpenRouter, Anthropic, and OpenAI-compatible endpoints.
class RemoteAiFoodService implements AiFoodService {
  static const int dailyLimit = 20;
  RemoteAiFoodService({
    required this.provider,
    required this.model,
    this.baseUrl = '',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final AiProvider provider;
  final String model;
  final String baseUrl;
  final http.Client _client;
  String? _apiKey;

  @override
  bool get isInitialized => hasApiKey && model.trim().isNotEmpty;

  @override
  String get providerId => provider.name;

  static Future<int> getRemainingRequests(AiProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    final date = _today();
    if (prefs.getString('ai_request_date_${provider.name}') != date) {
      return dailyLimit;
    }
    return (dailyLimit -
            (prefs.getInt('ai_request_count_${provider.name}') ?? 0))
        .clamp(0, dailyLimit)
        .toInt();
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<bool> _incrementRequestCount() async {
    final prefs = await SharedPreferences.getInstance();
    final date = _today();
    final dateKey = 'ai_request_date_${provider.name}';
    final countKey = 'ai_request_count_${provider.name}';
    final current =
        prefs.getString(dateKey) == date ? prefs.getInt(countKey) ?? 0 : 0;
    if (current >= dailyLimit) return false;
    await prefs.setString(dateKey, date);
    await prefs.setInt(countKey, current + 1);
    return true;
  }

  Future<void> _decrementRequestCount() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'ai_request_count_${provider.name}';
    final current = prefs.getInt(key) ?? 0;
    if (current > 0) await prefs.setInt(key, current - 1);
  }

  @override
  bool get hasApiKey => _apiKey?.isNotEmpty == true;

  @override
  ServiceResult<void> initialize(String apiKey) {
    if (apiKey.trim().isEmpty) {
      return const Failure(ServiceErrorType.authFailed, 'API key is required');
    }
    if (model.trim().isEmpty) {
      return const Failure(ServiceErrorType.parseError, 'Model is required');
    }
    if (provider == AiProvider.custom &&
        Uri.tryParse(baseUrl)?.scheme != 'https') {
      return const Failure(
        ServiceErrorType.parseError,
        'A valid HTTPS API endpoint is required.',
      );
    }
    _apiKey = apiKey.trim();
    return const Success(null);
  }

  @override
  Future<ServiceResult<List<FoodAnalysis>>> analyzeFoodMultiple(
    List<File> imageFiles, {
    String? correctionHint,
  }) async {
    if (!isInitialized) return _notInitialized<List<FoodAnalysis>>();
    if (imageFiles.isEmpty) return const Success([]);
    final hint = correctionHint == null || correctionHint.isEmpty
        ? ''
        : '\n\nUser correction: $correctionHint';
    final prompt =
        '''Identify each visible food and estimate portion size and nutrition. Return only JSON: {"foods":[{"name":"food name","portion_grams":100,"calories":200,"protein":10,"carbs":20,"fat":8,"fiber":3}]}. If no food is visible, return {"foods":[]}.$hint''';
    return _guard<List<FoodAnalysis>>(() async {
      final content = await _complete(prompt, images: imageFiles);
      final root = _jsonObject(content);
      final foods = (root['foods'] as List<dynamic>? ?? []).whereType<Map>();
      return foods
          .map(
            (item) => FoodAnalysis(
              name: item['name']?.toString() ?? 'Unknown food',
              portionGrams: _number(item['portion_grams']) ?? 100,
              calories: _number(item['calories']) ?? 0,
              protein: _number(item['protein']) ?? 0,
              carbs: _number(item['carbs']) ?? 0,
              fat: _number(item['fat']) ?? 0,
              fiber: _number(item['fiber']) ?? 0,
            ),
          )
          .toList();
    });
  }

  @override
  Future<ServiceResult<FoodAnalysis?>> reanalyzeSingleFood(
    List<File> imageFiles, {
    required FoodAnalysis currentFood,
    required String correctionHint,
    List<FoodAnalysis> confirmedFoods = const [],
  }) async {
    if (!isInitialized) return _notInitialized<FoodAnalysis?>();
    final confirmed = confirmedFoods.isEmpty
        ? 'None'
        : confirmedFoods.map((food) => food.name).join(', ');
    final prompt =
        '''Re-evaluate this food in the image and return only its corrected nutrition as JSON {"foods":[{"name":"${currentFood.name}","portion_grams":100,"calories":200,"protein":10,"carbs":20,"fat":8,"fiber":3}]}. User correction: $correctionHint. Do not include other foods. If not identifiable return {"foods":[]}.''';
    final result = await analyzeFoodMultiple(
      imageFiles,
      correctionHint: '$prompt Already confirmed foods to exclude: $confirmed.',
    );
    return switch (result) {
      Success<List<FoodAnalysis>>(value: final foods) =>
        Success(foods.firstOrNull),
      Failure<List<FoodAnalysis>>(
        errorType: final type,
        message: final message
      ) =>
        Failure(type, message),
    };
  }

  @override
  Future<ServiceResult<RecipeExtraction>> extractRecipeFromImage(
    File image,
  ) async {
    if (!isInitialized) return _notInitialized<RecipeExtraction>();
    const prompt =
        '''Extract the recipe and estimated total nutrition. Return only JSON: {"recipe_name":"Name","servings":4,"ingredients":[{"name":"ingredient","amount":100,"unit":"g","category":"other"}],"total_nutrition":{"calories":0,"protein":0,"carbs":0,"fat":0,"fiber":0}}. If unreadable, return empty values.''';
    return _guard<RecipeExtraction>(() async {
      final root = _jsonObject(await _complete(prompt, images: [image]));
      final nutrition = root['total_nutrition'] as Map? ?? const {};
      final ingredients = (root['ingredients'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map(
            (item) => ExtractedIngredient(
              name: item['name']?.toString() ?? '',
              amount: _number(item['amount']) ?? 0,
              unit: item['unit']?.toString() ?? 'g',
              category: item['category']?.toString() ?? 'other',
            ),
          )
          .where((item) => item.name.isNotEmpty)
          .toList();
      return RecipeExtraction(
        recipeName: _nullableString(root['recipe_name']),
        servings: (root['servings'] as num?)?.toInt() ?? 1,
        ingredients: ingredients,
        totalCalories: _number(nutrition['calories']) ?? 0,
        totalProtein: _number(nutrition['protein']) ?? 0,
        totalCarbs: _number(nutrition['carbs']) ?? 0,
        totalFat: _number(nutrition['fat']) ?? 0,
        totalFiber: _number(nutrition['fiber']) ?? 0,
      );
    });
  }

  @override
  Future<ServiceResult<NutritionLabelResult?>> parseNutritionImage(
    File image, {
    String? ocrText,
  }) async {
    const prompt =
        '''Read the nutrition label. Use printed per 100 g or 100 ml values and never estimate absent values. Return only JSON with keys product_name, brand, calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, fiber_per_100g, nutrition_unit, serving_size_g, serving_name, serving_to_100_converted. Use null for missing values.''';
    return _parseLabel(prompt, image: image, ocrText: ocrText);
  }

  @override
  Future<ServiceResult<NutritionLabelResult?>> parseNutritionText(String text) {
    const prompt =
        '''Read nutrition facts from the OCR text. Use only values explicitly printed per 100 g or 100 ml; never estimate or calculate. Return only JSON with keys product_name, brand, calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, fiber_per_100g, nutrition_unit, serving_size_g, serving_name, serving_to_100_converted. Use null for missing values.''';
    return _parseLabel(prompt, ocrText: text);
  }

  Future<ServiceResult<NutritionLabelResult?>> _parseLabel(
    String prompt, {
    File? image,
    String? ocrText,
  }) {
    if (!isInitialized) {
      return Future.value(_notInitialized<NutritionLabelResult?>());
    }
    return _guard<NutritionLabelResult?>(() async {
      final response = await _complete(
        '$prompt\n\n${ocrText == null ? '' : 'OCR text:\n$ocrText'}',
        images: image == null ? const [] : [image],
      );
      final root = _jsonObject(response);
      double? value(String key) => _number(root[key]);
      final calories = value('calories_per_100g');
      final protein = value('protein_per_100g');
      final carbs = value('carbs_per_100g');
      final fat = value('fat_per_100g');
      final fiber = value('fiber_per_100g');
      final present = <NutritionLabelField>{
        if (calories != null) NutritionLabelField.calories,
        if (protein != null) NutritionLabelField.protein,
        if (carbs != null) NutritionLabelField.carbs,
        if (fat != null) NutritionLabelField.fat,
        if (fiber != null) NutritionLabelField.fiber,
      };
      if (present.isEmpty) return null;
      return NutritionLabelResult(
        productName: _nullableString(root['product_name']),
        brand: _nullableString(root['brand']),
        caloriesPer100g: calories ?? 0,
        proteinPer100g: protein ?? 0,
        carbsPer100g: carbs ?? 0,
        fatPer100g: fat ?? 0,
        fiberPer100g: fiber ?? 0,
        nutritionUnit:
            NutritionUnitX.fromStorage(root['nutrition_unit']?.toString()),
        servingSizeG: value('serving_size_g'),
        servingName: _nullableString(root['serving_name']),
        wasServingConverted: root['serving_to_100_converted'] == true,
        presentFields: present,
      );
    });
  }

  Future<String> _complete(
    String prompt, {
    List<File> images = const [],
  }) async {
    if (!await _incrementRequestCount()) {
      throw const _AiLimitException();
    }
    try {
      final imageData = <Map<String, Object>>[];
      for (final file in images) {
        final bytes = await file.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded == null) {
          throw const FormatException(
            'The selected image format is not supported by this AI provider.',
          );
        }
        final oriented = img.bakeOrientation(decoded);
        final scale =
            math.min(1.0, 1600 / math.max(oriented.width, oriented.height));
        final resized = scale < 1
            ? img.copyResize(
                oriented,
                width: (oriented.width * scale).round(),
                height: (oriented.height * scale).round(),
              )
            : oriented;
        imageData.add({
          'data': base64Encode(img.encodeJpg(resized, quality: 84)),
          'mime': 'image/jpeg',
        });
      }
      final uri = _requestUri();
      final headers = _headers();
      final body = provider == AiProvider.anthropic
          ? _anthropicBody(prompt, imageData)
          : _chatBody(prompt, imageData);
      final response = await _client
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 45));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = response.body.length > 400
            ? response.body.substring(0, 400)
            : response.body;
        throw HttpException(
          'AI request failed (${response.statusCode}): $detail',
        );
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (provider == AiProvider.anthropic) {
        final content = decoded['content'] as List<dynamic>? ?? const [];
        return content
            .whereType<Map>()
            .map((part) => part['text']?.toString() ?? '')
            .join();
      }
      final choices = decoded['choices'] as List<dynamic>? ?? const [];
      final message = (choices.firstOrNull as Map?)?['message'] as Map?;
      final content = message?['content'];
      if (content is String) return content;
      if (content is List) {
        return content
            .whereType<Map>()
            .map((part) => part['text']?.toString() ?? '')
            .join();
      }
      throw const FormatException('The AI provider returned no text content.');
    } catch (_) {
      await _decrementRequestCount();
      rethrow;
    }
  }

  Uri _requestUri() {
    final root = switch (provider) {
      AiProvider.openAi => 'https://api.openai.com/v1',
      AiProvider.openRouter => 'https://openrouter.ai/api/v1',
      AiProvider.anthropic => 'https://api.anthropic.com',
      AiProvider.custom => baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
      AiProvider.gemini => '',
    };
    final path =
        provider == AiProvider.anthropic ? '/v1/messages' : '/chat/completions';
    return Uri.parse('$root$path');
  }

  Map<String, String> _headers() {
    if (provider == AiProvider.anthropic) {
      return {
        'x-api-key': _apiKey!,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      };
    }
    final headers = <String, String>{
      'Authorization': 'Bearer $_apiKey',
      'content-type': 'application/json',
    };
    if (provider == AiProvider.openRouter) {
      headers['X-Title'] = 'Sophis';
    }
    return headers;
  }

  Map<String, Object> _chatBody(
    String prompt,
    List<Map<String, Object>> images,
  ) {
    final content = <Map<String, Object>>[
      {'type': 'text', 'text': prompt},
      ...images.map(
        (image) => {
          'type': 'image_url',
          'image_url': {
            'url': 'data:${image['mime']};base64,${image['data']}',
          },
        },
      ),
    ];
    return {
      'model': model,
      'messages': [
        {'role': 'user', 'content': content},
      ],
      'response_format': {'type': 'json_object'},
    };
  }

  Map<String, Object> _anthropicBody(
    String prompt,
    List<Map<String, Object>> images,
  ) =>
      {
        'model': model,
        'max_tokens': 2048,
        'messages': [
          {
            'role': 'user',
            'content': [
              ...images.map(
                (image) => {
                  'type': 'image',
                  'source': {
                    'type': 'base64',
                    'media_type': image['mime'],
                    'data': image['data'],
                  },
                },
              ),
              {
                'type': 'text',
                'text': '$prompt\nReturn only a valid JSON object.',
              },
            ],
          },
        ],
      };

  Map<String, dynamic> _jsonObject(String text) {
    var cleaned = text.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\s*```$'), '');
    }
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) cleaned = cleaned.substring(start, end + 1);
    return jsonDecode(cleaned) as Map<String, dynamic>;
  }

  double? _number(Object? value) {
    if (value is num) return value.toDouble();
    return value is String ? double.tryParse(value.replaceAll(',', '.')) : null;
  }

  String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty || text.toLowerCase() == 'null'
        ? null
        : text;
  }

  Future<ServiceResult<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on TimeoutException {
      return const Failure(
        ServiceErrorType.network,
        'AI request timed out. Please try again.',
      );
    } on FormatException catch (error) {
      return Failure(ServiceErrorType.parseError, error.message);
    } on HttpException catch (error) {
      final message = error.message;
      final type = message.contains('(401)') || message.contains('(403)')
          ? ServiceErrorType.authFailed
          : message.contains('(429)')
              ? ServiceErrorType.rateLimited
              : ServiceErrorType.network;
      return Failure(type, message);
    } on _AiLimitException {
      return const Failure(
        ServiceErrorType.rateLimited,
        'Daily AI limit reached (20 requests per provider). Try again tomorrow.',
      );
    } catch (error) {
      return Failure(ServiceErrorType.unknown, 'AI request failed: $error');
    }
  }

  Failure<T> _notInitialized<T>() => const Failure(
        ServiceErrorType.unknown,
        'AI provider is not initialized. Check the selected provider and API key.',
      );

  @override
  void dispose() => _client.close();
}

class _AiLimitException implements Exception {
  const _AiLimitException();
}
