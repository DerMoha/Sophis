import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:sophis/models/nutrition_label_draft.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/serving_size.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/gemini_food_service.dart';
import 'package:sophis/services/nutrition_label_parser.dart';
import 'package:sophis/services/nutrition_label_validator.dart';
import 'package:sophis/services/nutrition_image_quality_service.dart';
import 'package:sophis/services/nutrition_image_preprocessor.dart';
import 'package:sophis/services/nutrition_label_ai_provider.dart';
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
  final NutritionLabelValidation validation;
  final NutritionLabelAnalysisSource source;

  const LabelIntakeResult({
    required this.label,
    required this.product,
    required this.validation,
    required this.source,
  });
}

enum LabelIntakeProgress {
  checkingImage,
  readingText,
  enhancingImage,
  verifyingValues,
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
  static const Duration _pipelineTimeout = Duration(seconds: 38);
  static const Duration _qualityTimeout = Duration(seconds: 6);
  static const Duration _preprocessingTimeout = Duration(seconds: 7);
  static const Duration _ocrTimeout = Duration(seconds: 8);

  final TextRecognizer _recognizer;
  final GeminiFoodService? _gemini;
  final AiProviderRegistry _aiProviders;
  final NutritionImageQualityService _qualityService;
  final NutritionImagePreprocessor _preprocessor;
  String? _lastDraftPath;
  NutritionLabelDraft? _lastDraft;

  LabelIntakeFlow({
    GeminiFoodService? gemini,
    AiProviderRegistry? aiProviderRegistry,
    NutritionImageQualityService qualityService =
        const NutritionImageQualityService(),
    NutritionImagePreprocessor preprocessor =
        const NutritionImagePreprocessor(),
  })  : _recognizer = TextRecognizer(script: TextRecognitionScript.latin),
        _gemini = gemini,
        _aiProviders = aiProviderRegistry ?? _registryForGemini(gemini),
        _qualityService = qualityService,
        _preprocessor = preprocessor;

  static AiProviderRegistry _registryForGemini(GeminiFoodService? gemini) {
    final registry = AiProviderRegistry();
    if (gemini != null) {
      registry.register(GeminiNutritionLabelAiProvider(gemini));
    }
    return registry;
  }

  bool get hasGeminiFallback => _gemini?.hasApiKey ?? false;

  /// Run the full pipeline on an image file. Returns a ServiceResult so the
  /// caller can surface the failure message without knowing about the
  /// underlying parser or Gemini types.
  Future<ServiceResult<LabelIntakeResult>> processImage(
    LabelIntakeRequest request, {
    ValueChanged<LabelIntakeProgress>? onProgress,
    bool allowCloudAssist = false,
  }) async {
    _lastDraftPath = request.imageFile.path;
    _lastDraft = null;
    try {
      return await _processImage(
        request,
        onProgress: onProgress,
        allowCloudAssist: allowCloudAssist,
      ).timeout(_pipelineTimeout);
    } on TimeoutException {
      return const Failure(
        ServiceErrorType.network,
        'Nutrition label analysis timed out. Please try again.',
      );
    }
  }

  /// Returns the nullable OCR draft even when the full intake flow cannot
  /// produce a confirmable product. Callers can use it to let the user fill
  /// in one lost row instead of forcing a complete rescan.
  Future<ServiceResult<NutritionLabelDraft>> processDraftImage(
    LabelIntakeRequest request, {
    ValueChanged<LabelIntakeProgress>? onProgress,
    bool allowCloudAssist = false,
  }) async {
    if (_lastDraftPath == request.imageFile.path && _lastDraft != null) {
      return Success(_lastDraft!);
    }
    _lastDraftPath = request.imageFile.path;
    _lastDraft = null;
    try {
      return await _processDraftImage(
        request,
        onProgress: onProgress,
        allowCloudAssist: allowCloudAssist,
      ).timeout(_pipelineTimeout);
    } on TimeoutException {
      return const Failure(
        ServiceErrorType.network,
        'Nutrition label analysis timed out. Please try again.',
      );
    }
  }

  Future<ServiceResult<NutritionLabelDraft>> _processDraftImage(
    LabelIntakeRequest request, {
    ValueChanged<LabelIntakeProgress>? onProgress,
    required bool allowCloudAssist,
  }) async {
    onProgress?.call(LabelIntakeProgress.checkingImage);
    final quality = await _qualityService
        .inspect(request.imageFile)
        .timeout(_qualityTimeout);
    if (!quality.isAcceptable) {
      return Failure(ServiceErrorType.parseError, quality.message);
    }

    onProgress?.call(LabelIntakeProgress.readingText);
    final documents = <_RecognizedNutritionDocument>[];
    final original = await _recognize(request.imageFile);
    if (original != null) documents.add(original);

    var prepared = const <File>[];
    try {
      onProgress?.call(LabelIntakeProgress.enhancingImage);
      prepared = await _preprocessor
          .prepareCandidates(request.imageFile)
          .timeout(_preprocessingTimeout);
      for (final candidate in prepared) {
        onProgress?.call(LabelIntakeProgress.readingText);
        final document = await _recognize(candidate);
        if (document != null) documents.add(document);
      }
    } catch (error) {
      debugPrint('Nutrition draft preprocessing failed: $error');
    } finally {
      await _preprocessor.cleanUpCandidates(prepared);
    }

    final resolution = _resolveDocuments(documents);
    final document = resolution?.document ?? _bestDocument(documents);
    NutritionLabelDraft? draft = document == null
        ? null
        : NutritionLabelParser.parseDraft(document.text);
    _lastDraft = draft;
    Failure<NutritionLabelDraft>? cloudFailure;

    if (allowCloudAssist && (draft == null || !draft.hasRequiredNutrition)) {
      final provider = _aiProviders.defaultProvider;
      if (provider != null) {
        final cloudResult = await provider.readLabel(
          image: request.imageFile,
          supportingOcrText: document?.text,
        );
        switch (cloudResult) {
          case Success<NutritionLabelDraft>(value: final cloudDraft):
            draft =
                draft == null ? cloudDraft : _mergeDrafts(draft, cloudDraft);
            _lastDraft = draft;
          case Failure<NutritionLabelDraft>():
            cloudFailure = cloudResult;
        }
      }
    }

    if (draft != null) return Success(draft);
    if (cloudFailure != null) {
      return Failure(cloudFailure.errorType, cloudFailure.message);
    }
    return const Failure(
      ServiceErrorType.parseError,
      'Could not read any nutrition values from the label.',
    );
  }

  NutritionLabelDraft _mergeDrafts(
    NutritionLabelDraft local,
    NutritionLabelDraft cloud,
  ) {
    final cloudHasNutrition = cloud.hasAnyNutrition;
    return NutritionLabelDraft(
      productName: cloud.productName ?? local.productName,
      brand: cloud.brand ?? local.brand,
      caloriesPer100: cloud.caloriesPer100 ?? local.caloriesPer100,
      proteinPer100: cloud.proteinPer100 ?? local.proteinPer100,
      carbsPer100: cloud.carbsPer100 ?? local.carbsPer100,
      fatPer100: cloud.fatPer100 ?? local.fatPer100,
      fiberPer100: cloud.fiberPer100 ?? local.fiberPer100,
      nutritionUnit:
          cloudHasNutrition ? cloud.nutritionUnit : local.nutritionUnit,
      servingAmount: cloud.servingAmount ?? local.servingAmount,
      servingName: cloud.servingName ?? local.servingName,
      analysisSource:
          cloudHasNutrition ? cloud.analysisSource : local.analysisSource,
    );
  }

  Future<ServiceResult<LabelIntakeResult>> _processImage(
    LabelIntakeRequest request, {
    ValueChanged<LabelIntakeProgress>? onProgress,
    required bool allowCloudAssist,
  }) async {
    onProgress?.call(LabelIntakeProgress.checkingImage);
    final quality = await _qualityService
        .inspect(request.imageFile)
        .timeout(_qualityTimeout);
    if (!quality.isAcceptable) {
      return Failure(ServiceErrorType.parseError, quality.message);
    }

    onProgress?.call(LabelIntakeProgress.readingText);
    final documents = <_RecognizedNutritionDocument>[];
    final originalDocument = await _recognize(request.imageFile);
    if (originalDocument != null) documents.add(originalDocument);
    _rememberDraft(originalDocument?.text);

    if (originalDocument != null) {
      final originalLabel = originalDocument.parsedLabel;
      if (originalLabel != null &&
          NutritionLabelValidator.validate(originalLabel).isHighConfidence &&
          originalDocument.isUnambiguous) {
        return _processParsedText(
          ocrText: originalDocument.text,
          localLabel: originalLabel,
          imageFile: request.imageFile,
          idGenerator: request.idGenerator,
          fallbackProductName: request.fallbackProductName,
          fallbackBrand: request.fallbackBrand,
          barcode: request.barcode,
          allowCloudAssist: allowCloudAssist,
        );
      }
    }

    var prepared = const <File>[];
    try {
      onProgress?.call(LabelIntakeProgress.enhancingImage);
      prepared = await _preprocessor
          .prepareCandidates(request.imageFile)
          .timeout(_preprocessingTimeout);
      for (final candidate in prepared) {
        onProgress?.call(LabelIntakeProgress.readingText);
        final document = await _recognize(candidate);
        if (document != null) documents.add(document);
      }
    } catch (error) {
      // Preprocessing is an enhancement, not a hard dependency. The original
      // recognition result can still be parsed locally or by the AI fallback.
      debugPrint('Nutrition image preprocessing failed: $error');
    } finally {
      await _preprocessor.cleanUpCandidates(prepared);
    }

    final resolution = _resolveDocuments(documents);
    final document = resolution?.document ?? _bestDocument(documents);
    if (document == null || document.text.trim().isEmpty) {
      onProgress?.call(LabelIntakeProgress.verifyingValues);
      return _processParsedText(
        ocrText: '',
        localLabel: null,
        imageFile: request.imageFile,
        idGenerator: request.idGenerator,
        fallbackProductName: request.fallbackProductName,
        fallbackBrand: request.fallbackBrand,
        barcode: request.barcode,
        allowCloudAssist: allowCloudAssist,
      );
    }
    _rememberDraft(document.text);
    onProgress?.call(LabelIntakeProgress.verifyingValues);
    return _processParsedText(
      ocrText: document.text,
      localLabel: resolution?.label ?? document.parsedLabel,
      localValidation: resolution?.validation,
      imageFile: request.imageFile,
      idGenerator: request.idGenerator,
      fallbackProductName: request.fallbackProductName,
      fallbackBrand: request.fallbackBrand,
      barcode: request.barcode,
      allowCloudAssist: allowCloudAssist,
    );
  }

  _LocalLabelResolution? _resolveDocuments(
    List<_RecognizedNutritionDocument> documents,
  ) {
    final usable = documents.where((document) {
      final label = document.parsedLabel;
      return label != null && NutritionLabelValidator.validate(label).isUsable;
    }).toList();
    if (usable.isEmpty) return null;

    final clusters = <List<_RecognizedNutritionDocument>>[];
    for (final document in usable) {
      final matching = clusters.where(
        (cluster) => _labelsAgree(
          cluster.first.parsedLabel!,
          document.parsedLabel!,
        ),
      );
      if (matching.isEmpty) {
        clusters.add([document]);
      } else {
        matching.first.add(document);
      }
    }
    clusters.sort((a, b) {
      final countComparison = b.length.compareTo(a.length);
      if (countComparison != 0) return countComparison;
      final aScore = a.map(_documentScore).reduce((x, y) => x > y ? x : y);
      final bScore = b.map(_documentScore).reduce((x, y) => x > y ? x : y);
      return bScore.compareTo(aScore);
    });

    final winningCluster = clusters.first;
    final ranked = [...winningCluster]
      ..sort((a, b) => _documentScore(b).compareTo(_documentScore(a)));
    final document = ranked.first;
    final label = _mergeLabels(
      winningCluster.map((candidate) => candidate.parsedLabel!).toList(),
      preferred: document.parsedLabel!,
    );
    final baseValidation = NutritionLabelValidator.validate(label);
    final hasConsensus = winningCluster.length >= 2;
    final hasStrongSingle = usable.length == 1 && document.isUnambiguous;
    final hasReliableLocalResult = hasConsensus || hasStrongSingle;
    final validation = hasReliableLocalResult
        ? baseValidation
        : NutritionLabelValidation(
            isUsable: baseValidation.isUsable,
            isHighConfidence: false,
            issues: [
              ...baseValidation.issues,
              NutritionLabelIssue.candidateDisagreement,
            ],
          );
    return _LocalLabelResolution(
      document: document,
      label: label,
      validation: validation,
    );
  }

  bool _labelsAgree(NutritionLabelResult a, NutritionLabelResult b) {
    final pairs = [
      (a.caloriesPer100g, b.caloriesPer100g, 15.0, 0.08),
      (a.proteinPer100g, b.proteinPer100g, 1.5, 0.2),
      (a.carbsPer100g, b.carbsPer100g, 1.5, 0.2),
      (a.fatPer100g, b.fatPer100g, 1.5, 0.2),
      (a.fiberPer100g, b.fiberPer100g, 1.5, 0.25),
    ];
    final matching = pairs.where((pair) {
      final (left, right, absoluteTolerance, relativeTolerance) = pair;
      final tolerance = absoluteTolerance +
          (left.abs() + right.abs()) / 2 * relativeTolerance;
      return (left - right).abs() <= tolerance;
    }).length;
    return matching >= 4;
  }

  NutritionLabelResult _mergeLabels(
    List<NutritionLabelResult> labels, {
    required NutritionLabelResult preferred,
  }) {
    double median(double Function(NutritionLabelResult label) select) {
      final values = labels.map(select).toList()..sort();
      final middle = values.length ~/ 2;
      return values.length.isOdd
          ? values[middle]
          : (values[middle - 1] + values[middle]) / 2;
    }

    return preferred.copyWith(
      caloriesPer100g: median((label) => label.caloriesPer100g),
      proteinPer100g: median((label) => label.proteinPer100g),
      carbsPer100g: median((label) => label.carbsPer100g),
      fatPer100g: median((label) => label.fatPer100g),
      fiberPer100g: median((label) => label.fiberPer100g),
    );
  }

  _RecognizedNutritionDocument? _bestDocument(
    List<_RecognizedNutritionDocument> documents,
  ) {
    if (documents.isEmpty) return null;
    final ranked = [...documents]
      ..sort((a, b) => _documentScore(b).compareTo(_documentScore(a)));
    return ranked.first;
  }

  int _documentScore(_RecognizedNutritionDocument document) {
    final label = document.parsedLabel;
    final validation =
        label == null ? null : NutritionLabelValidator.validate(label);
    final parseScore = validation == null
        ? 0
        : validation.isHighConfidence
            ? 100
            : validation.isUsable
                ? 60
                : 20;
    return parseScore + _nutritionTextScore(document.text);
  }

  int _nutritionTextScore(String text) {
    final keywords = RegExp(
      r'N.hr|Nutri|Energ|Brenn|Fett|Fat|Kohl|Carb|Eiwei|Protein|Ballast|Fiber|Salz|Salt',
      caseSensitive: false,
    ).allMatches(text).length;
    final values = RegExp(
      r'\d+[\.,]?\d*\s*(?:kcal|kJ|g)',
      caseSensitive: false,
    ).allMatches(text).length;
    return keywords * 3 + values;
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
    bool allowCloudAssist = false,
  }) async {
    return _processParsedText(
      ocrText: ocrText,
      localLabel: NutritionLabelParser.parse(ocrText),
      idGenerator: idGenerator,
      fallbackProductName: fallbackProductName,
      fallbackBrand: fallbackBrand,
      barcode: barcode,
      allowCloudAssist: allowCloudAssist,
    );
  }

  NutritionLabelDraft? parseDraftText(String ocrText) =>
      NutritionLabelParser.parseDraft(ocrText);

  Future<ServiceResult<LabelIntakeResult>> _processParsedText({
    required String ocrText,
    required NutritionLabelResult? localLabel,
    required String Function() idGenerator,
    NutritionLabelValidation? localValidation,
    File? imageFile,
    String? fallbackProductName,
    String? fallbackBrand,
    String? barcode,
    bool allowCloudAssist = false,
  }) async {
    final effectiveLocalValidation = localValidation ??
        (localLabel == null
            ? null
            : NutritionLabelValidator.validate(localLabel));
    var label = localLabel;
    var source = NutritionLabelAnalysisSource.localOcr;
    Failure<NutritionLabelResult?>? geminiFailure;

    if (allowCloudAssist &&
        (effectiveLocalValidation == null ||
            !effectiveLocalValidation.isHighConfidence)) {
      final geminiResult = await _tryGemini(
        ocrText: ocrText,
        imageFile: imageFile,
      );
      switch (geminiResult) {
        case Success<NutritionLabelResult?>(value: final geminiLabel):
          if (geminiLabel != null &&
              NutritionLabelValidator.validate(geminiLabel).isUsable) {
            label = geminiLabel;
            source = NutritionLabelAnalysisSource.gemini;
          }
        case final Failure<NutritionLabelResult?> failure:
          geminiFailure = failure;
      }
    }

    if (label == null) {
      if (geminiFailure case final failure?) {
        return Failure(failure.errorType, failure.message);
      }
      return const Failure(
        ServiceErrorType.parseError,
        'Could not parse nutrition values from the label',
      );
    }

    final validation = source == NutritionLabelAnalysisSource.localOcr &&
            effectiveLocalValidation != null
        ? effectiveLocalValidation
        : NutritionLabelValidator.validate(label);
    if (!validation.isUsable) {
      if (geminiFailure case final failure?) {
        return Failure(failure.errorType, failure.message);
      }
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

    return Success(
      LabelIntakeResult(
        label: label,
        product: product,
        validation: validation,
        source: source,
      ),
    );
  }

  Future<ServiceResult<NutritionLabelResult?>> _tryGemini({
    required String ocrText,
    File? imageFile,
  }) async {
    if (imageFile != null) {
      final provider = _aiProviders.defaultProvider;
      if (provider == null) return const Success(null);
      final result = await provider.readLabel(
        image: imageFile,
        supportingOcrText: ocrText,
      );
      return switch (result) {
        Success<NutritionLabelDraft>(value: final draft) =>
          _rememberAndReturnCloudResult(draft),
        Failure<NutritionLabelDraft>(
          errorType: final type,
          message: final message,
        ) =>
          Failure(type, message),
      };
    }
    final gemini = _gemini;
    if (gemini == null || !gemini.hasApiKey) return const Success(null);
    return gemini.parseNutritionText(ocrText);
  }

  Success<NutritionLabelResult?> _rememberAndReturnCloudResult(
    NutritionLabelDraft draft,
  ) {
    final merged =
        _lastDraft == null ? draft : _mergeDrafts(_lastDraft!, draft);
    _lastDraft = merged;
    return Success(merged.toResult());
  }

  void _rememberDraft(String? text) {
    if (text == null || text.trim().isEmpty) return;
    final draft = NutritionLabelParser.parseDraft(text);
    if (draft != null) _lastDraft = draft;
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
      servings.addAll(
        ServingSize.generateFractions(
          servingName,
          servingSizeG,
          unit: label.nutritionUnit,
        ),
      );
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
      nutritionUnit: label.nutritionUnit,
      barcode: barcode,
      brand: label.brand ?? fallbackBrand,
      servings: servings,
    );
  }

  /// Builds a product from a reviewed draft without exposing the rest of the
  /// scanner pipeline to UI callers.
  FoodItem productFromLabel({
    required NutritionLabelResult label,
    required String Function() idGenerator,
    String? fallbackProductName,
    String? fallbackBrand,
    String? barcode,
  }) =>
      _buildProduct(
        label: label,
        idGenerator: idGenerator,
        fallbackProductName: fallbackProductName,
        fallbackBrand: fallbackBrand,
        barcode: barcode,
      );

  Future<_RecognizedNutritionDocument?> _recognize(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText =
          await _recognizer.processImage(inputImage).timeout(_ocrTimeout);
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

  NutritionLabelResult? get parsedLabel =>
      NutritionLabelParser.parseLayout(lines);

  bool get isUnambiguous {
    final hasPer100Heading = RegExp(
      r'(?:per|pro|je|pour|por|w)\s*100\s*(?:g|ml)',
      caseSensitive: false,
    ).hasMatch(text);
    if (!hasPer100Heading) return false;

    for (final line in lines) {
      final lower = line.text.toLowerCase();
      final isMacroRow = RegExp(
        r'protein|eiwei|carbo|kohlen|glucides|koolhyd|fett|fat|vetten|fiber|fibre|ballast',
        caseSensitive: false,
      ).hasMatch(lower);
      final isEnergyRow = RegExp(
        r'energie|energy|brennwert|calories',
        caseSensitive: false,
      ).hasMatch(lower);
      if (!isMacroRow && !isEnergyRow) continue;
      final valueTokens = line.tokens.where((token) {
        final tokenText = token.text.toLowerCase();
        if (isEnergyRow) return tokenText.contains('kcal');
        return RegExp(r'\d').hasMatch(tokenText) &&
            !tokenText.contains('kj') &&
            !tokenText.contains('kcal');
      }).length;
      if (valueTokens > 1) return false;
    }
    return true;
  }
}

class _LocalLabelResolution {
  final _RecognizedNutritionDocument document;
  final NutritionLabelResult label;
  final NutritionLabelValidation validation;

  const _LocalLabelResolution({
    required this.document,
    required this.label,
    required this.validation,
  });
}
