import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:sophis/services/android_paddle_ocr.dart';
import 'package:sophis/models/nutrition_label_draft.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/serving_size.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/ai_food_service.dart';
import 'package:sophis/services/nutrition_label_parser.dart';
import 'package:sophis/services/nutrition_label_validator.dart';
import 'package:sophis/services/nutrition_image_quality_service.dart';
import 'package:sophis/services/nutrition_image_preprocessor.dart';
import 'package:sophis/services/nutrition_table_mapper.dart';
import 'package:sophis/services/on_device_label_reader.dart';
import 'package:sophis/services/nutrition_label_ai_provider.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/scan_model_service.dart';

/// Inputs for a single label-intake scan. The flow owns the OCR + parsing +
/// Cloud-AI fallback policy; the caller only provides the bits of context that
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
  preparingScanner,
  checkingImage,
  readingText,
  enhancingImage,
  verifyingValues,
}

/// Deep service that owns the label-intake pipeline:
/// 1. ML Kit OCR extraction
/// 2. Local regex parser (NutritionLabelParser)
/// 3. Selected cloud AI fallback when local parsing fails
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
  final AiFoodService? _aiService;
  final AiProviderRegistry _aiProviders;
  final NutritionImageQualityService _qualityService;
  final NutritionImagePreprocessor _preprocessor;
  final ScanModelService _scanModels;
  String? _lastDraftPath;
  NutritionLabelDraft? _lastDraft;
  String? _lastOcrText;
  String? _lastDocumentText;
  final OnDeviceLabelReader _onDeviceReader;
  _LabelScanAttempt? _activeAttempt;
  bool _disposed = false;

  LabelIntakeFlow({
    ScanModelService scanModels = const ScanModelService(),
    AiFoodService? aiService,
    AiFoodService? gemini,
    AiProviderRegistry? aiProviderRegistry,
    NutritionImageQualityService qualityService =
        const NutritionImageQualityService(),
    NutritionImagePreprocessor preprocessor =
        const NutritionImagePreprocessor(),
    OnDeviceLabelReader onDeviceReader = const OnDeviceLabelReader(),
  })  : _onDeviceReader = onDeviceReader,
        _recognizer = TextRecognizer(script: TextRecognitionScript.latin),
        _aiService = aiService ?? gemini,
        _aiProviders =
            aiProviderRegistry ?? _registryForCloudAi(aiService ?? gemini),
        _qualityService = qualityService,
        _preprocessor = preprocessor,
        _scanModels = scanModels;

  static AiProviderRegistry _registryForCloudAi(AiFoodService? aiService) {
    final registry = AiProviderRegistry();
    if (aiService != null) {
      registry.register(CloudNutritionLabelAiProvider(aiService));
    }
    return registry;
  }

  bool get hasCloudAiFallback => _aiService?.hasApiKey ?? false;
  bool get hasGeminiFallback => hasCloudAiFallback;

  /// Run the full pipeline on an image file. Returns a ServiceResult so the
  /// caller can surface the failure message without knowing about the
  /// underlying parser or Gemini types.
  Future<ServiceResult<LabelIntakeResult>> processImage(
    LabelIntakeRequest request, {
    ValueChanged<LabelIntakeProgress>? onProgress,
    bool allowCloudAssist = false,
  }) async {
    onProgress?.call(LabelIntakeProgress.preparingScanner);
    final readiness = AndroidPaddleOcr.enabled
        ? await const AndroidPaddleOcr().prepare()
        : await _scanModels.ensureAvailable(ScanModel.ocr);
    if (readiness case Failure<void>()) {
      return Failure(readiness.errorType, readiness.message);
    }
    _lastDraftPath = request.imageFile.path;
    _lastDraft = null;
    _lastOcrText = null;
    _lastDocumentText = null;
    final attempt = _beginAttempt();
    try {
      return await _processImage(
        request,
        attempt: attempt,
        onProgress: onProgress,
        allowCloudAssist: allowCloudAssist,
      ).timeout(_pipelineTimeout);
    } on TimeoutException {
      attempt.cancelled = true;
      return const Failure(
        ServiceErrorType.network,
        'Nutrition label analysis timed out. Please try again.',
      );
    } finally {
      if (identical(_activeAttempt, attempt)) _activeAttempt = null;
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
    onProgress?.call(LabelIntakeProgress.preparingScanner);
    final readiness = AndroidPaddleOcr.enabled
        ? await const AndroidPaddleOcr().prepare()
        : await _scanModels.ensureAvailable(ScanModel.ocr);
    if (readiness case Failure<void>()) {
      return Failure(readiness.errorType, readiness.message);
    }
    _lastDraftPath = request.imageFile.path;
    _lastDraft = null;
    final attempt = _beginAttempt();
    try {
      return await _processDraftImage(
        request,
        attempt: attempt,
        onProgress: onProgress,
        allowCloudAssist: allowCloudAssist,
      ).timeout(_pipelineTimeout);
    } on TimeoutException {
      attempt.cancelled = true;
      return const Failure(
        ServiceErrorType.network,
        'Nutrition label analysis timed out. Please try again.',
      );
    } finally {
      if (identical(_activeAttempt, attempt)) _activeAttempt = null;
    }
  }

  Future<ServiceResult<NutritionLabelDraft>> _processDraftImage(
    LabelIntakeRequest request, {
    required _LabelScanAttempt attempt,
    ValueChanged<LabelIntakeProgress>? onProgress,
    required bool allowCloudAssist,
  }) async {
    attempt.check();
    onProgress?.call(LabelIntakeProgress.checkingImage);
    final quality = await _qualityService
        .inspect(request.imageFile)
        .timeout(_qualityTimeout);
    attempt.check();
    if (!quality.isAcceptable) {
      return Failure(ServiceErrorType.parseError, quality.message);
    }

    onProgress?.call(LabelIntakeProgress.readingText);
    final documents = <_RecognizedNutritionDocument>[];
    final original = await _recognize(request.imageFile);
    attempt.check();
    if (original != null) documents.add(original);

    var prepared = const <File>[];
    try {
      onProgress?.call(LabelIntakeProgress.enhancingImage);
      prepared = await _prepareCandidates(
        request.imageFile,
        original?.lines ?? const [],
      );
      for (final candidate in prepared) {
        attempt.check();
        onProgress?.call(LabelIntakeProgress.readingText);
        final document = await _recognize(candidate);
        if (document != null) documents.add(document);
      }
    } catch (error) {
      debugPrint('Nutrition draft preprocessing failed: $error');
    } finally {
      await _preprocessor.cleanUpCandidates(prepared);
    }
    attempt.check();

    final resolution = _resolveDocuments(documents);
    final document = resolution?.document ?? _bestDocument(documents);
    NutritionLabelDraft? draft = resolution != null
        ? NutritionLabelDraft.fromResult(resolution.label)
        : document?.draft;
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
    // A cloud result is one coherent reading. Mixing cells can combine bases.
    return cloud.hasAnyNutrition ? cloud : local;
  }

  Future<ServiceResult<LabelIntakeResult>> _processImage(
    LabelIntakeRequest request, {
    required _LabelScanAttempt attempt,
    ValueChanged<LabelIntakeProgress>? onProgress,
    required bool allowCloudAssist,
  }) async {
    attempt.check();
    onProgress?.call(LabelIntakeProgress.readingText);
    // Tier 1: Apple's table reader already pairs each label with its value.
    final tableLabel = await _readTable(request.imageFile);
    attempt.check();
    final tableValidation = tableLabel == null
        ? null
        : NutritionLabelValidator.validate(tableLabel);
    // A printed "<" bound still needs the user's estimate; the review screen
    // asks for it, so it does not need the slower line-based reader.
    if (tableLabel != null &&
        tableLabel.hasRequiredNutrition &&
        tableValidation!.isUsable &&
        tableValidation.issues.every(
          (issue) => issue == NutritionLabelIssue.upperBoundValue,
        )) {
      _lastDraft = NutritionLabelDraft.fromResult(tableLabel);
      return _processParsedText(
        ocrText: '',
        localLabel: tableLabel,
        localValidation: tableValidation,
        imageFile: request.imageFile,
        idGenerator: request.idGenerator,
        fallbackProductName: request.fallbackProductName,
        fallbackBrand: request.fallbackBrand,
        barcode: request.barcode,
        allowCloudAssist: allowCloudAssist,
      );
    }

    final result = await _processImageWithOcr(
      request,
      attempt: attempt,
      onProgress: onProgress,
      allowCloudAssist: allowCloudAssist,
    );
    if (result is Success<LabelIntakeResult>) return result;
    if (tableLabel != null) {
      // The line-based reader failed; keep whichever reading found more.
      final tableDraft = NutritionLabelDraft.fromResult(tableLabel);
      if (_presentCount(tableDraft) > _presentCount(_lastDraft)) {
        _lastDraft = tableDraft;
      }
      if (tableLabel.hasRequiredNutrition && tableValidation!.isUsable) {
        return _processParsedText(
          ocrText: '',
          localLabel: tableLabel,
          localValidation: tableValidation,
          imageFile: request.imageFile,
          idGenerator: request.idGenerator,
          fallbackProductName: request.fallbackProductName,
          fallbackBrand: request.fallbackBrand,
          barcode: request.barcode,
          allowCloudAssist: allowCloudAssist,
        );
      }
    }

    // Tier 2: the on-device model pairs rows the readers could not, e.g.
    // multilingual labels or values printed a line below their names.
    attempt.check();
    onProgress?.call(LabelIntakeProgress.verifyingValues);
    final ocrText = [_lastDocumentText, _lastOcrText]
        .whereType<String>()
        .where((text) => text.trim().isNotEmpty)
        .join('\n\n');
    final modelLabel = await _onDeviceReader.read(ocrText);
    attempt.check();
    if (modelLabel == null) return result;
    // A model reading is used only when complete and the printed energy
    // matches the macros. Partial readings never prefill the review screen:
    // a wrong prefilled value is worse than an empty field.
    final modelValidation = NutritionLabelValidator.validate(modelLabel);
    if (!modelLabel.hasRequiredNutrition ||
        !modelValidation.isUsable ||
        modelValidation.issues
            .contains(NutritionLabelIssue.calorieMacroMismatch)) {
      return result;
    }
    _lastDraft = NutritionLabelDraft.fromResult(modelLabel);
    // Model readings are always shown for review, even when plausible.
    return _processParsedText(
      ocrText: ocrText,
      localLabel: modelLabel,
      localValidation: NutritionLabelValidation(
        isUsable: true,
        isHighConfidence: false,
        issues: [...modelValidation.issues, NutritionLabelIssue.modelReading],
      ),
      imageFile: request.imageFile,
      idGenerator: request.idGenerator,
      fallbackProductName: request.fallbackProductName,
      fallbackBrand: request.fallbackBrand,
      barcode: request.barcode,
      allowCloudAssist: allowCloudAssist,
    );
  }

  static int _presentCount(NutritionLabelDraft? draft) => draft == null
      ? 0
      : [
          draft.caloriesPer100,
          draft.proteinPer100,
          draft.carbsPer100,
          draft.fatPer100,
          draft.fiberPer100,
        ].whereType<double>().length;

  /// Rows of cells from iOS 26+ document recognition, mapped to values.
  /// Null on other platforms, older iOS, or when no table is found.
  Future<NutritionLabelResult?> _readTable(File imageFile) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        const bool.fromEnvironment('USE_MLKIT_OCR')) {
      return null;
    }
    try {
      final raw = await const MethodChannel('sophis/nutrition_text')
          .invokeMapMethod<String, dynamic>(
        'recognizeDocument',
        {'path': imageFile.path},
      ).timeout(_ocrTimeout);
      final tables = [
        for (final table in (raw?['tables'] as List<dynamic>? ?? const []))
          [
            for (final row in table as List<dynamic>)
              [for (final cell in row as List<dynamic>) cell as String],
          ],
      ];
      _lastDocumentText = raw?['text'] as String?;
      return NutritionTableMapper.map(tables);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint('Nutrition table reader unavailable: ${error.code}');
      return null;
    } on TimeoutException {
      return null;
    }
  }

  Future<ServiceResult<LabelIntakeResult>> _processImageWithOcr(
    LabelIntakeRequest request, {
    required _LabelScanAttempt attempt,
    ValueChanged<LabelIntakeProgress>? onProgress,
    required bool allowCloudAssist,
  }) async {
    attempt.check();
    onProgress?.call(LabelIntakeProgress.checkingImage);
    final quality = await _qualityService
        .inspect(request.imageFile)
        .timeout(_qualityTimeout);
    attempt.check();
    if (!quality.isAcceptable) {
      return Failure(ServiceErrorType.parseError, quality.message);
    }

    onProgress?.call(LabelIntakeProgress.readingText);
    final documents = <_RecognizedNutritionDocument>[];
    final originalDocument = await _recognize(request.imageFile);
    attempt.check();
    if (originalDocument != null) documents.add(originalDocument);
    _rememberDraft(originalDocument);

    if (originalDocument != null) {
      final originalLabel = originalDocument.parsedLabel;
      if (!AndroidPaddleOcr.enabled &&
          originalLabel != null &&
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
      prepared = await _prepareCandidates(
        request.imageFile,
        originalDocument?.lines ?? const [],
      );
      for (final candidate in prepared) {
        attempt.check();
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
    attempt.check();

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
    _rememberDraft(document);
    if (resolution != null) {
      _lastDraft = NutritionLabelDraft.fromResult(resolution.label);
    }
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

  @visibleForTesting
  ({NutritionLabelResult label, NutritionLabelValidation validation})?
      resolveOcrCandidates(List<List<NutritionOcrLine>> candidates) {
    final resolution = _resolveDocuments([
      for (final lines in candidates)
        _RecognizedNutritionDocument(
          text: lines.map((line) => line.text).join('\n'),
          lines: lines,
        ),
    ]);
    if (resolution == null) return null;
    return (label: resolution.label, validation: resolution.validation);
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
      final aScore = a.map(_documentScore).reduce((x, y) => x > y ? x : y);
      final bScore = b.map(_documentScore).reduce((x, y) => x > y ? x : y);
      final scoreComparison = bScore.compareTo(aScore);
      if (scoreComparison != 0) return scoreComparison;
      final countComparison = b.length.compareTo(a.length);
      if (countComparison != 0) return countComparison;
      // Prefer the original capture on ties, before enhanced variants.
      return documents.indexOf(a.first).compareTo(documents.indexOf(b.first));
    });

    final winningCluster = clusters.first;
    final ranked = [...winningCluster]
      ..sort((a, b) => _documentScore(b).compareTo(_documentScore(a)));
    final document = ranked.first;
    // Keep one observed label intact; averaging can invent unprinted values.
    final selectedLabel = document.parsedLabel!;
    // If another reading of the same values saw a '<', retain that evidence.
    // Losing a faint qualifier must never turn an upper limit into an exact value.
    final label = selectedLabel.copyWith(
      upperBoundFields: {
        ...selectedLabel.upperBoundFields,
        for (final candidate in usable)
          if (_labelsAgree(
            selectedLabel,
            candidate.parsedLabel!,
            compareBounds: false,
          ))
            ...candidate.parsedLabel!.upperBoundFields,
      },
    );
    final baseValidation = NutritionLabelValidator.validate(label);
    final hasConsensus = winningCluster.length >= 2 && clusters.length == 1;
    final hasStrongSingle = usable.length == 1 && document.isUnambiguous;
    final hasReliableLocalResult =
        (hasConsensus && document.hasExplicitBasis) || hasStrongSingle;
    final missingUnits = label.presentFields
        .difference({NutritionLabelField.calories})
        .difference(label.explicitUnitFields)
        .isNotEmpty;
    final validation = hasReliableLocalResult && !missingUnits
        ? baseValidation
        : NutritionLabelValidation(
            isUsable: baseValidation.isUsable,
            isHighConfidence: false,
            issues: [
              ...baseValidation.issues,
              if (!hasReliableLocalResult)
                NutritionLabelIssue.candidateDisagreement,
              if (missingUnits) NutritionLabelIssue.missingUnitEvidence,
            ],
          );
    return _LocalLabelResolution(
      document: document,
      label: label,
      validation: validation,
    );
  }

  bool _labelsAgree(
    NutritionLabelResult a,
    NutritionLabelResult b, {
    bool compareBounds = true,
  }) {
    if (a.nutritionUnit != b.nutritionUnit ||
        (compareBounds && !setEquals(a.upperBoundFields, b.upperBoundFields)) ||
        !setEquals(a.presentFields, b.presentFields)) {
      return false;
    }
    final pairs = [
      (a.caloriesPer100g, b.caloriesPer100g),
      (a.proteinPer100g, b.proteinPer100g),
      (a.carbsPer100g, b.carbsPer100g),
      (a.fatPer100g, b.fatPer100g),
      (a.fiberPer100g, b.fiberPer100g),
    ];
    // These are readings of the same printed values, not estimates from
    // different foods. Every field must agree to claim OCR consensus.
    return pairs.every((pair) => (pair.$1 - pair.$2).abs() < 0.01);
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
        : validation.isUsable &&
                !validation.issues
                    .contains(NutritionLabelIssue.calorieMacroMismatch)
            ? 100
            : validation.isUsable
                ? 60
                : 20;
    // A printed upper limit is valid evidence, unlike a calorie/macro conflict.
    // Extra packaging text is not evidence of a better nutrition reading.
    // Among valid readings prefer complete fields, then the original capture.
    return parseScore * 100 +
        (label?.explicitUnitFields.length ?? 0) * 10 +
        (label?.presentFields.length ?? _nutritionTextScore(document.text));
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
            source = _aiService?.providerId == 'gemini'
                ? NutritionLabelAnalysisSource.gemini
                : NutritionLabelAnalysisSource.cloudAi;
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
    final aiService = _aiService;
    if (aiService == null || !aiService.hasApiKey) return const Success(null);
    return aiService.parseNutritionText(ocrText);
  }

  Success<NutritionLabelResult?> _rememberAndReturnCloudResult(
    NutritionLabelDraft draft,
  ) {
    final merged =
        _lastDraft == null ? draft : _mergeDrafts(_lastDraft!, draft);
    _lastDraft = merged;
    return Success(merged.toResult());
  }

  void _rememberDraft(_RecognizedNutritionDocument? document) {
    final draft = document?.draft;
    if (draft != null) _lastDraft = draft;
    final text = document?.text;
    if (text != null && text.length > (_lastOcrText?.length ?? 0)) {
      _lastOcrText = text;
    }
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
      if (AndroidPaddleOcr.enabled) {
        final lines = await const AndroidPaddleOcr().recognize(imageFile);
        if (lines.isEmpty) return null;
        _traceOcr(imageFile, lines);
        return _RecognizedNutritionDocument(
          text: lines.map((line) => line.text).join('\n'),
          lines: lines,
        );
      }
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.iOS &&
          !const bool.fromEnvironment('USE_MLKIT_OCR')) {
        try {
          final raw = await const MethodChannel('sophis/nutrition_text')
              .invokeListMethod<dynamic>(
            'recognize',
            {'path': imageFile.path},
          ).timeout(_ocrTimeout);
          final lines = (raw ?? []).map((value) {
            final line = Map<String, dynamic>.from(value as Map);
            return NutritionOcrLine(
              text: line['text'] as String,
              top: (line['top'] as num).toDouble(),
              height: (line['height'] as num).toDouble(),
              left: (line['left'] as num).toDouble(),
              right: (line['right'] as num).toDouble(),
              tokens: (line['tokens'] as List<dynamic>).map((value) {
                final token = Map<String, dynamic>.from(value as Map);
                return NutritionOcrToken(
                  text: token['text'] as String,
                  centerX: (token['centerX'] as num).toDouble(),
                  centerY: (token['centerY'] as num).toDouble(),
                );
              }).toList(),
            );
          }).toList()
            ..sort((a, b) => a.top.compareTo(b.top));
          if (lines.isNotEmpty) {
            _traceOcr(imageFile, lines);
            return _RecognizedNutritionDocument(
              text: lines.map((line) => line.text).join('\n'),
              lines: lines,
            );
          }
        } on MissingPluginException {
          // Older host/test builds can still use the portable reader.
        } on PlatformException catch (error) {
          debugPrint('Native nutrition OCR unavailable: ${error.code}');
        }
      }
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
              height: line.boundingBox.height,
              left: line.boundingBox.left,
              right: line.boundingBox.right,
              tokens: line.elements
                  .map(
                    (element) => NutritionOcrToken(
                      text: element.text,
                      centerX: element.boundingBox.center.dx,
                      centerY: element.boundingBox.center.dy,
                    ),
                  )
                  .toList(),
            ),
          );
        }
      }
      lines.sort((a, b) => a.top.compareTo(b.top));
      _traceOcr(imageFile, lines);
      return _RecognizedNutritionDocument(
        text: recognizedText.text,
        lines: lines,
      );
    } catch (e) {
      debugPrint('Nutrition OCR failed: $e');
      return null;
    }
  }

  void _traceOcr(File file, List<NutritionOcrLine> lines) {
    if (!const bool.fromEnvironment('CAPTURE_LABEL_OCR')) return;
    debugPrint('OCR_JSON:${jsonEncode({
          'candidate': file.path,
          'lines': [
            for (final line in lines)
              {
                'text': line.text,
                'top': line.top,
                'height': line.height,
                'left': line.left,
                'right': line.right,
                'tokens': [
                  for (final token in line.tokens)
                    {
                      'text': token.text,
                      'centerX': token.centerX,
                      'centerY': token.centerY,
                    },
                ],
              },
          ],
        })}');
  }

  void dispose() {
    _disposed = true;
    _activeAttempt?.cancelled = true;
    _recognizer.close();
    _aiService?.dispose();
  }

  _LabelScanAttempt _beginAttempt() {
    _activeAttempt?.cancelled = true;
    return _activeAttempt = (_LabelScanAttempt()..cancelled = _disposed);
  }

  Future<List<File>> _prepareCandidates(
    File file,
    List<NutritionOcrLine> lines,
  ) {
    final pending = _preprocessor.prepareCandidates(file, lines: lines);
    return pending.timeout(
      _preprocessingTimeout,
      onTimeout: () {
        // A timeout does not cancel native work or an isolate. Clean up late files.
        unawaited(
          pending
              .then(_preprocessor.cleanUpCandidates)
              .catchError((Object error) {
            debugPrint('Late nutrition preprocessing cleanup failed: $error');
          }),
        );
        throw TimeoutException('Nutrition image preprocessing timed out');
      },
    );
  }
}

class _LabelScanAttempt {
  bool cancelled = false;

  void check() {
    if (cancelled) throw TimeoutException('Nutrition scan cancelled');
  }
}

class _RecognizedNutritionDocument {
  final String text;
  final List<NutritionOcrLine> lines;

  const _RecognizedNutritionDocument({required this.text, required this.lines});

  NutritionLabelResult? get parsedLabel =>
      NutritionLabelParser.parseLayout(lines);

  NutritionLabelDraft? get draft {
    final label = parsedLabel;
    if (label != null) return NutritionLabelDraft.fromResult(label);
    // Do not reintroduce unsafe text-order values after layout parsing fails.
    if (hasExplicitBasis) return null;
    return NutritionLabelParser.parseDraft(text);
  }

  bool get hasExplicitBasis => NutritionLabelParser.hasPer100Heading(text);

  bool get isUnambiguous {
    if (!hasExplicitBasis) return false;
    final label = parsedLabel;
    if (label == null ||
        label.presentFields
            .difference({NutritionLabelField.calories})
            .difference(label.explicitUnitFields)
            .isNotEmpty) {
      return false;
    }
    // Separate OCR blocks can hide the second column from token counts.
    if (RegExp(r'portion|serving|%\s*RI', caseSensitive: false)
        .hasMatch(text)) {
      return false;
    }

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
