import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/serving_size.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/gemini_food_service.dart';
import 'package:sophis/services/nutrition_label_parser.dart';
import 'package:sophis/services/nutrition_label_validator.dart';
import 'package:sophis/services/service_result.dart';

/// Inputs for a single label-intake scan. The flow owns the OCR + parsing +
/// Gemini-fallback policy; the caller only provides the bits of context that
/// vary by entry point (scanner vs. barcode-not-found recovery).
class LabelIntakeRequest {
  final File imageFile;
  final String Function() idGenerator;
  final String? fallbackProductName;
  final String? fallbackBrand;
  final String? barcode;

  const LabelIntakeRequest({
    required this.imageFile,
    required this.idGenerator,
    this.fallbackProductName,
    this.fallbackBrand,
    this.barcode,
  });
}

/// Output of a successful scan. `label` is the raw parsed result (kept for
/// preview rendering) and `product` is the constructed FoodItem ready to hand
/// to PortionPickerSheet or to cache as a barcode correction.
class LabelIntakeResult {
  final NutritionLabelResult label;
  final FoodItem product;

  const LabelIntakeResult({required this.label, required this.product});
}

/// Deep service that owns the label-intake pipeline:
/// 1. ML Kit OCR extraction
/// 2. Local regex parser (NutritionLabelParser)
/// 3. Gemini fallback (parseNutritionText) when local parse fails
/// 4. Calorie-sentinel validation
/// 5. ServingSize generation
/// 6. FoodItem construction
/// 7. id generation (caller-supplied, so the scanner screen can use a UUID
///    and the barcode sheet can use the actual barcode).
///
/// Hides all of this behind a single `processImage` call. `processOcrText`
/// is exposed for unit testing without a camera or a Gemini key.
class LabelIntakeFlow {
  final TextRecognizer _recognizer;
  final GeminiFoodService? _gemini;

  LabelIntakeFlow({GeminiFoodService? gemini})
      : _recognizer = TextRecognizer(script: TextRecognitionScript.latin),
        _gemini = gemini;

  bool get hasGeminiFallback => _gemini?.hasApiKey ?? false;

  /// Run the full pipeline on an image file. Returns a ServiceResult so the
  /// caller can surface the failure message without knowing about the
  /// underlying parser or Gemini types.
  Future<ServiceResult<LabelIntakeResult>> processImage(
    LabelIntakeRequest request,
  ) async {
    final document = await _recognize(request.imageFile);
    if (document == null || document.text.trim().isEmpty) {
      return const Failure(
        ServiceErrorType.parseError,
        'No text found in image',
      );
    }

    return _processParsedText(
      ocrText: document.text,
      localLabel: NutritionLabelParser.parseLayout(document.lines),
      idGenerator: request.idGenerator,
      fallbackProductName: request.fallbackProductName,
      fallbackBrand: request.fallbackBrand,
      barcode: request.barcode,
    );
  }

  /// Pure pipeline: OCR text -> `ServiceResult<LabelIntakeResult>`.
  /// Exposed (not private) so the pipeline can be unit-tested without a
  /// camera, an image picker, or a Gemini API key.
  Future<ServiceResult<LabelIntakeResult>> processOcrText({
    required String ocrText,
    required String Function() idGenerator,
    String? fallbackProductName,
    String? fallbackBrand,
    String? barcode,
  }) async {
    return _processParsedText(
      ocrText: ocrText,
      localLabel: NutritionLabelParser.parse(ocrText),
      idGenerator: idGenerator,
      fallbackProductName: fallbackProductName,
      fallbackBrand: fallbackBrand,
      barcode: barcode,
    );
  }

  Future<ServiceResult<LabelIntakeResult>> _processParsedText({
    required String ocrText,
    required NutritionLabelResult? localLabel,
    required String Function() idGenerator,
    String? fallbackProductName,
    String? fallbackBrand,
    String? barcode,
  }) async {
    final localValidation = localLabel == null
        ? null
        : NutritionLabelValidator.validate(localLabel);
    var label = localLabel;

    if (localValidation == null || !localValidation.isHighConfidence) {
      final geminiLabel = await _tryGemini(ocrText);
      if (geminiLabel != null &&
          NutritionLabelValidator.validate(geminiLabel).isUsable) {
        label = geminiLabel;
      }
    }

    if (label == null) {
      return const Failure(
        ServiceErrorType.parseError,
        'Could not parse nutrition values from the label',
      );
    }

    if (!NutritionLabelValidator.validate(label).isUsable) {
      return const Failure(
        ServiceErrorType.parseError,
        'Could not read nutrition values from the label',
      );
    }

    final product = _buildProduct(
      label: label,
      idGenerator: idGenerator,
      fallbackProductName: fallbackProductName,
      fallbackBrand: fallbackBrand,
      barcode: barcode,
    );

    return Success(LabelIntakeResult(label: label, product: product));
  }

  Future<NutritionLabelResult?> _tryGemini(
    String ocrText,
  ) async {
    final gemini = _gemini;
    if (gemini == null || !gemini.hasApiKey) {
      return null;
    }
    final result = await gemini.parseNutritionText(ocrText);
    return switch (result) {
      Success<NutritionLabelResult?>(value: final r) => r,
      Failure<NutritionLabelResult?>() => null,
    };
  }

  FoodItem _buildProduct({
    required NutritionLabelResult label,
    required String Function() idGenerator,
    String? fallbackProductName,
    String? fallbackBrand,
    String? barcode,
  }) {
    final servings = <ServingSize>[];
    final servingSizeG = label.servingSizeG;
    if (servingSizeG != null && servingSizeG > 0) {
      final servingName = label.servingName ?? 'Portion';
      servings.addAll(ServingSize.generateFractions(servingName, servingSizeG));
    }

    return FoodItem(
      id: idGenerator(),
      name: label.productName ?? fallbackProductName ?? 'Scanned Product',
      category: 'food',
      caloriesPer100g: label.caloriesPer100g,
      proteinPer100g: label.proteinPer100g,
      carbsPer100g: label.carbsPer100g,
      fatPer100g: label.fatPer100g,
      fiberPer100g: label.fiberPer100g,
      barcode: barcode,
      brand: label.brand ?? fallbackBrand,
      servings: servings,
    );
  }

  Future<_RecognizedNutritionDocument?> _recognize(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _recognizer.processImage(inputImage);
      if (recognizedText.text.isEmpty) return null;
      final lines = <NutritionOcrLine>[];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          lines.add(
            NutritionOcrLine(
              text: line.text,
              top: line.boundingBox.top,
              tokens: line.elements
                  .map(
                    (element) => NutritionOcrToken(
                      text: element.text,
                      centerX: element.boundingBox.center.dx,
                    ),
                  )
                  .toList(),
            ),
          );
        }
      }
      lines.sort((a, b) => a.top.compareTo(b.top));
      return _RecognizedNutritionDocument(
        text: recognizedText.text,
        lines: lines,
      );
    } catch (e) {
      debugPrint('ML Kit OCR failed: $e');
      return null;
    }
  }

  void dispose() {
    _recognizer.close();
    _gemini?.dispose();
  }
}

class _RecognizedNutritionDocument {
  final String text;
  final List<NutritionOcrLine> lines;

  const _RecognizedNutritionDocument({required this.text, required this.lines});
}
