import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:image/image.dart' as img;

import 'package:sophis/services/gemini/models/food_analysis.dart';
import 'package:sophis/services/service_result.dart';

/// On-device food recognition backed by the active flutter_gemma model.
class LocalAiFoodService {
  LocalAiFoodService({
    this.modelType = ModelType.gemma4,
    this.preferredBackend = PreferredBackend.gpu,
    this.maxTokens = 2048,
  });

  static bool _pluginInitialized = false;

  final ModelType modelType;
  final PreferredBackend preferredBackend;
  final int maxTokens;

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<ServiceResult<void>> initialize({String? huggingFaceToken}) async {
    try {
      await _ensurePluginInitialized(huggingFaceToken: huggingFaceToken);

      if (!FlutterGemma.hasActiveModel()) {
        _isInitialized = false;
        return const Failure(
          ServiceErrorType.notFound,
          'No local AI model is installed. Install a Gemma vision model first.',
        );
      }

      _isInitialized = true;
      return const Success(null);
    } catch (e) {
      _isInitialized = false;
      debugPrint('Local AI initialization failed: $e');
      return Failure(
        ServiceErrorType.unknown,
        'Failed to initialize local AI: $e',
      );
    }
  }

  Future<ServiceResult<List<String>>> listInstalledModels() async {
    try {
      await _ensurePluginInitialized();
      return Success(await FlutterGemma.listInstalledModels());
    } catch (e) {
      debugPrint('Failed to list local AI models: $e');
      return Failure(
        ServiceErrorType.unknown,
        'Failed to list local AI models: $e',
      );
    }
  }

  Future<ServiceResult<bool>> hasActiveModel() async {
    try {
      await _ensurePluginInitialized();
      return Success(FlutterGemma.hasActiveModel());
    } catch (e) {
      debugPrint('Failed to check local AI model: $e');
      return Failure(
        ServiceErrorType.unknown,
        'Failed to check local AI model: $e',
      );
    }
  }

  Future<ServiceResult<String>> installModelFromFile(
    String path, {
    ModelType? modelType,
    ModelFileType fileType = ModelFileType.litertlm,
  }) async {
    try {
      await _ensurePluginInitialized();
      final installation = await FlutterGemma.installModel(
        modelType: modelType ?? this.modelType,
        fileType: fileType,
      ).fromFile(path).install();
      _isInitialized = true;
      return Success(installation.modelId);
    } catch (e) {
      debugPrint('Failed to install local AI model from file: $e');
      return Failure(
        ServiceErrorType.unknown,
        'Failed to install local AI model: $e',
      );
    }
  }

  Future<ServiceResult<String>> installModelFromNetwork(
    String url, {
    String? token,
    ModelType? modelType,
    ModelFileType fileType = ModelFileType.litertlm,
    void Function(int progress)? onProgress,
  }) async {
    try {
      await _ensurePluginInitialized();
      var builder = FlutterGemma.installModel(
        modelType: modelType ?? this.modelType,
        fileType: fileType,
      ).fromNetwork(url, token: token);

      if (onProgress != null) {
        builder = builder.withProgress(onProgress);
      }

      final installation = await builder.install();
      _isInitialized = true;
      return Success(installation.modelId);
    } catch (e) {
      debugPrint('Failed to install local AI model from network: $e');
      return Failure(
        ServiceErrorType.network,
        'Failed to download local AI model: $e',
      );
    }
  }

  Future<ServiceResult<List<FoodAnalysis>>> analyzeFood(File imageFile) async {
    return analyzeFoodMultiple([imageFile]);
  }

  Future<ServiceResult<List<FoodAnalysis>>> analyzeFoodMultiple(
    List<File> imageFiles, {
    String? correctionHint,
  }) async {
    if (!_isInitialized) {
      return const Failure(
        ServiceErrorType.notFound,
        'Local AI service is not initialized',
      );
    }

    if (imageFiles.isEmpty) {
      return const Success([]);
    }

    InferenceModel? model;
    InferenceChat? chat;

    try {
      final imageBytes = await _buildImageBytes(imageFiles);
      model = await _createModel(imageFiles.length);
      chat = await model.createChat(
        temperature: 0.2,
        topK: 1,
        supportImage: true,
        modelType: modelType,
        systemInstruction: _systemInstruction,
      );

      await chat.addQueryChunk(
        Message.withImage(
          text: _buildFoodPrompt(correctionHint: correctionHint),
          imageBytes: imageBytes.first,
          isUser: true,
        ),
      );

      for (var index = 1; index < imageBytes.length; index += 1) {
        await chat.addQueryChunk(
          Message.imageOnly(
            text: 'Additional view ${index + 1}.',
            imageBytes: imageBytes[index],
            isUser: true,
          ),
        );
      }

      final response =
          await chat.generateChatResponse().timeout(const Duration(minutes: 2));

      if (response is! TextResponse || response.token.trim().isEmpty) {
        return const Success([]);
      }

      return Success(_parseResponse(response.token));
    } on TimeoutException {
      debugPrint('Local AI food analysis timed out');
      return const Failure(
        ServiceErrorType.unknown,
        'Local AI analysis timed out. Try fewer images or a smaller model.',
      );
    } catch (e) {
      debugPrint('Local AI food analysis failed: $e');
      return Failure(ServiceErrorType.unknown, 'Failed to analyze image: $e');
    } finally {
      await chat?.close();
      await model?.close();
    }
  }

  Future<void> _ensurePluginInitialized({String? huggingFaceToken}) async {
    if (_pluginInitialized) return;

    await FlutterGemma.initialize(huggingFaceToken: huggingFaceToken);
    _pluginInitialized = true;
  }

  Future<InferenceModel> _createModel(int imageCount) async {
    try {
      return await FlutterGemma.getActiveModel(
        maxTokens: maxTokens,
        preferredBackend: preferredBackend,
        supportImage: true,
        maxNumImages: imageCount,
      );
    } catch (e) {
      if (preferredBackend == PreferredBackend.cpu) rethrow;

      debugPrint('Local AI preferred backend failed, retrying CPU: $e');
      return FlutterGemma.getActiveModel(
        maxTokens: maxTokens,
        preferredBackend: PreferredBackend.cpu,
        supportImage: true,
        maxNumImages: imageCount,
      );
    }
  }

  String _buildFoodPrompt({String? correctionHint}) {
    var promptText = '''
Analyze these food images and identify all visible food items.
For each food item, provide:
1. Specific food name
2. Estimated portion size in grams
3. Estimated calories
4. Estimated protein in grams
5. Estimated carbs in grams
6. Estimated fat in grams
''';

    if (correctionHint != null && correctionHint.isNotEmpty) {
      promptText += '\nIMPORTANT CORRECTION: $correctionHint\n';
    }

    promptText += '''

Respond ONLY with valid JSON in this exact format, no markdown and no extra text:
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

    return promptText;
  }

  List<FoodAnalysis> _parseResponse(String text) {
    try {
      final cleaned = _extractJsonObject(text);
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
      debugPrint(
        'Failed to parse local AI food response: $e\nRaw response: $text',
      );
      return [];
    }
  }

  String _extractJsonObject(String text) {
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
    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace == -1 || lastBrace == -1 || firstBrace >= lastBrace) {
      return cleaned;
    }

    return cleaned.substring(firstBrace, lastBrace + 1);
  }

  Future<List<Uint8List>> _buildImageBytes(List<File> files) async {
    final images = <Uint8List>[];
    for (final file in files) {
      images.add(await _convertImageToJpeg(file));
    }
    return images;
  }

  Future<Uint8List> _convertImageToJpeg(File file) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      final path = file.path;
      debugPrint('Failed to decode local AI image: $path');
      return Uint8List.fromList(bytes);
    }
    return Uint8List.fromList(img.encodeJpg(decoded, quality: 85));
  }

  void dispose() {
    _isInitialized = false;
  }
}

const String _systemInstruction = '''
You are a nutrition assistant. Estimate foods and macros from images.
Return machine-readable JSON only. Do not include markdown or explanations.
''';
