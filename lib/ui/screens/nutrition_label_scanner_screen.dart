import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/nutrition_label_draft.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/services/gemini_food_service.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/label_intake_flow.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/nutrition_scan_feedback_service.dart';
import 'package:sophis/ui/screens/label_review_screen.dart';
import 'package:sophis/ui/screens/nutrition_label_camera_screen.dart';
import 'package:sophis/ui/theme/app_theme.dart';

class NutritionLabelScannerScreen extends StatefulWidget {
  final String meal;
  final bool openCameraOnStart;

  const NutritionLabelScannerScreen({
    super.key,
    required this.meal,
    this.openCameraOnStart = true,
  });

  @override
  State<NutritionLabelScannerScreen> createState() =>
      _NutritionLabelScannerScreenState();
}

class _NutritionLabelScannerScreenState
    extends State<NutritionLabelScannerScreen> {
  final _picker = ImagePicker();
  late final LabelIntakeFlow _flow;

  bool _isAnalyzing = false;
  bool _cloudHelpAllowed = false;
  String? _error;
  LabelIntakeProgress _progress = LabelIntakeProgress.checkingImage;

  @override
  void initState() {
    super.initState();
    final apiKey = context.read<SettingsProvider>().geminiApiKey;
    final gemini = GeminiFoodService();
    if (apiKey != null && apiKey.isNotEmpty) {
      gemini.initialize(apiKey);
    }
    _flow = LabelIntakeFlow(gemini: gemini);
    _cloudHelpAllowed = _flow.hasGeminiFallback &&
        context.read<SettingsProvider>().labelCloudHelpEnabled;
    // Go straight to the camera; this screen only shows progress and retries.
    if (widget.openCameraOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _captureAndScan(closeOnCancel: true);
      });
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  Future<void> _captureAndScan({bool closeOnCancel = false}) async {
    final l10n = AppLocalizations.of(context)!;
    final captured = await Navigator.push<XFile>(
      context,
      MaterialPageRoute(
        builder: (_) => NutritionLabelCameraScreen(
          title: l10n.nutritionLabelScannerTitle,
          guidance: l10n.nutritionLabelCaptureGuide,
          allowGallery: true,
        ),
      ),
    );
    if (!mounted) return;
    if (captured == null) {
      if (closeOnCancel) Navigator.pop(context);
      return;
    }
    await _scanImage(captured);
  }

  Future<void> _pickFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 95,
    );
    if (picked != null) await _scanImage(picked);
  }

  Future<void> _scanImage(XFile picked) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      setState(() {
        _isAnalyzing = true;
        _error = null;
        _progress = LabelIntakeProgress.checkingImage;
      });

      final request = LabelIntakeRequest(
        imageFile: File(picked.path),
        idGenerator: () => 'scan-${const Uuid().v4()}',
        fallbackProductName: l10n.scannedProductName,
      );
      // Cloud help is a standing choice in Settings; no per-scan prompt.
      final result = await _flow.processImage(
        request,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
        allowCloudAssist: _cloudHelpAllowed,
      );
      if (!mounted) return;

      switch (result) {
        case Success<LabelIntakeResult>(value: final intake):
          await _openReview(
            draft: NutritionLabelDraft.fromResult(intake.label)
                .copyWith(analysisSource: intake.source),
            scanned: intake.label,
            needsReview: !intake.validation.isHighConfidence,
            outcome: intake.source == NutritionLabelAnalysisSource.gemini
                ? NutritionScanOutcome.cloudSuccess
                : NutritionScanOutcome.localSuccess,
          );
        case Failure<LabelIntakeResult>():
          // Show whatever was read; the review screen asks for the rest.
          final draftResult = await _flow.processDraftImage(request);
          if (!mounted) return;
          await _openReview(
            draft: draftResult.valueOrNull ??
                NutritionLabelDraft(productName: l10n.scannedProductName),
            needsReview: true,
            outcome: NutritionScanOutcome.partialManualCompletion,
          );
      }
    } on TimeoutException {
      if (mounted) {
        await _onFailure(fallback: l10n.errorNetworkTryAgain);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _error = l10n.nutritionLabelNotParsed;
        });
      }
    }
  }

  void _openManualFallback() {
    _openReview(
      draft: NutritionLabelDraft(
        productName: AppLocalizations.of(context)!.scannedProductName,
      ),
      needsReview: false,
    );
  }

  Future<void> _openReview({
    required NutritionLabelDraft draft,
    required bool needsReview,
    NutritionLabelResult? scanned,
    NutritionScanOutcome? outcome,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isAnalyzing = false);
    final result = await Navigator.push<LabelReviewOutcome>(
      context,
      AppTheme.slideRoute(
        LabelReviewScreen(
          draft: draft,
          meal: widget.meal,
          needsReview: needsReview,
          buildProduct: (label) => _flow.productFromLabel(
            label: label,
            idGenerator: () => 'scan-${const Uuid().v4()}',
            fallbackProductName: l10n.scannedProductName,
          ),
          onLogged: outcome == null
              ? null
              : (confirmed) => const NutritionScanFeedbackService().record(
                    scanned: scanned ?? confirmed,
                    confirmed: confirmed,
                    outcome: outcome,
                  ),
        ),
      ),
    );
    if (!mounted) return;
    switch (result) {
      case LabelReviewOutcome.rescan:
        await const NutritionScanFeedbackService().recordOutcome(
          NutritionScanOutcome.rescan,
        );
        if (mounted) await _captureAndScan();
      case LabelReviewOutcome.logged || null:
        Navigator.pop(context);
    }
  }

  Future<void> _onFailure({
    required String fallback,
  }) async {
    if (!mounted) return;
    setState(() {
      _isAnalyzing = false;
      _error = fallback;
    });
  }

  String _progressLabel(AppLocalizations l10n) => switch (_progress) {
        LabelIntakeProgress.preparingScanner => l10n.scannerPreparing,
        LabelIntakeProgress.checkingImage => l10n.nutritionLabelCheckingImage,
        LabelIntakeProgress.readingText => l10n.nutritionLabelReadingText,
        LabelIntakeProgress.enhancingImage => l10n.nutritionLabelEnhancingImage,
        LabelIntakeProgress.verifyingValues =>
          l10n.nutritionLabelVerifyingValues,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.nutritionLabelScannerTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMD,
                            ),
                          ),
                          child: Icon(
                            Icons.document_scanner_outlined,
                            size: 36,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          l10n.nutritionLabelScannerTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.nutritionLabelScannerDescription,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        _PrivacyNote(
                          theme: theme,
                          text: _cloudHelpAllowed
                              ? l10n.nutritionLabelAiFallbackEnabled
                              : l10n.nutritionLabelLocalOnly,
                          usesAiFallback: _cloudHelpAllowed,
                        ),
                        const SizedBox(height: 20),
                        _CaptureGuide(
                          theme: theme,
                          caption: l10n.nutritionLabelCaptureGuide,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSM,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 18,
                                  color: theme.colorScheme.error,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _error!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _openManualFallback,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: Text(l10n.nutritionLabelManualFallback),
                          ),
                        ],
                        if (_isAnalyzing) ...[
                          const SizedBox(height: 24),
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            _progressLabel(l10n),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (!_isAnalyzing)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _captureAndScan,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text(l10n.takePhoto),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(l10n.chooseFromGallery),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  final ThemeData theme;
  final String text;
  final bool usesAiFallback;

  const _PrivacyNote({
    required this.theme,
    required this.text,
    required this.usesAiFallback,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          usesAiFallback ? Icons.auto_awesome_outlined : Icons.phone_android,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _CaptureGuide extends StatelessWidget {
  final ThemeData theme;
  final String caption;

  const _CaptureGuide({required this.theme, required this.caption});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.7,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(
                  6,
                  (index) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: index == 0 ? 0.35 : 0.14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            caption,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
