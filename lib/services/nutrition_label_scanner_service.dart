import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/gemini_food_service.dart';
import 'package:sophis/services/nutrition_label_parser.dart';
import 'package:sophis/services/service_result.dart';

class NutritionLabelScannerService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  GeminiFoodService? _geminiFallback;

  bool get hasGeminiFallback =>
      _geminiFallback != null && _geminiFallback!.hasApiKey;

  void setGeminiFallback(GeminiFoodService service) {
    _geminiFallback = service;
  }

  Future<ServiceResult<NutritionLabelResult?>> scanLabel(File imageFile) async {
    final ocrText = await _extractText(imageFile);

    if (ocrText == null || ocrText.trim().isEmpty) {
      return const Failure(ServiceErrorType.parseError, 'No text found in image');
    }

    debugPrint('ML Kit OCR extracted ${ocrText.length} characters');

    final localResult = NutritionLabelParser.parse(ocrText);
    if (localResult != null) {
      debugPrint('Local parser succeeded');
      return Success(localResult);
    }

    debugPrint('Local parser failed, trying Gemini fallback');

    if (_geminiFallback != null && _geminiFallback!.hasApiKey) {
      return _geminiFallback!.parseNutritionText(ocrText);
    }

    return const Failure(
      ServiceErrorType.parseError,
      'Could not parse nutrition values from the label',
    );
  }

  Future<String?> _extractText(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final text = recognizedText.text;

      if (text.isEmpty) return null;
      return text;
    } catch (e) {
      debugPrint('ML Kit OCR failed: $e');
      return null;
    }
  }

  void dispose() {
    _textRecognizer.close();
    _geminiFallback?.dispose();
  }
}
