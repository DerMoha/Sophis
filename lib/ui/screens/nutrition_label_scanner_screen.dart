import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/services/gemini_food_service.dart';
import 'package:sophis/services/label_intake_flow.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/nutrition_scan_feedback_service.dart';
import 'package:sophis/ui/components/label_preview_sheet.dart';
import 'package:sophis/ui/components/portion_picker_sheet.dart';
import 'package:sophis/ui/theme/app_theme.dart';

class NutritionLabelScannerScreen extends StatefulWidget {
  final String meal;

  const NutritionLabelScannerScreen({super.key, required this.meal});

  @override
  State<NutritionLabelScannerScreen> createState() =>
      _NutritionLabelScannerScreenState();
}

class _NutritionLabelScannerScreenState
    extends State<NutritionLabelScannerScreen> {
  final _picker = ImagePicker();
  late final LabelIntakeFlow _flow;

  bool _isAnalyzing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final apiKey = context.read<SettingsProvider>().geminiApiKey;
    final gemini = GeminiFoodService();
    if (apiKey != null && apiKey.isNotEmpty) {
      gemini.initialize(apiKey);
    }
    _flow = LabelIntakeFlow(gemini: gemini);
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  Future<void> _pickAndScan(ImageSource source) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
      );

      if (picked == null) return;

      if (source == ImageSource.camera) {
        try {
          await Gal.putImage(picked.path);
        } catch (_) {}
      }

      setState(() {
        _isAnalyzing = true;
        _error = null;
      });

      final result = await _flow.processImage(
        LabelIntakeRequest(
          imageFile: File(picked.path),
          idGenerator: () => 'scan-${const Uuid().v4()}',
          fallbackProductName: l10n.scannedProductName,
        ),
      );

      if (!mounted) return;

      switch (result) {
        case Success<LabelIntakeResult>(value: final intake):
          await _onSuccess(intake);
        case Failure<LabelIntakeResult>(message: final message):
          await _onFailure(
            message: message,
            fallback: l10n.nutritionLabelNotParsed,
          );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _onSuccess(LabelIntakeResult intake) async {
    final confirmedLabel = await showLabelPreviewSheet(
      context: context,
      label: intake.label,
      validation: intake.validation,
    );

    if (!mounted) return;

    if (confirmedLabel == null) {
      setState(() {
        _isAnalyzing = false;
      });
      return;
    }

    await const NutritionScanFeedbackService().record(
      scanned: intake.label,
      confirmed: confirmedLabel,
    );

    if (!mounted) return;
    setState(() => _isAnalyzing = false);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PortionPickerSheet(
        item: intake.product.copyWith(
          name: confirmedLabel.productName,
          brand: confirmedLabel.brand,
          caloriesPer100g: confirmedLabel.caloriesPer100g,
          proteinPer100g: confirmedLabel.proteinPer100g,
          carbsPer100g: confirmedLabel.carbsPer100g,
          fatPer100g: confirmedLabel.fatPer100g,
          fiberPer100g: confirmedLabel.fiberPer100g,
        ),
        meal: widget.meal,
      ),
    );
  }

  Future<void> _onFailure({
    required String message,
    required String fallback,
  }) async {
    if (!mounted) return;
    setState(() {
      _isAnalyzing = false;
      _error = message.isNotEmpty ? message : fallback;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.nutritionLabelScannerTitle),
      ),
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
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD),
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
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSM),
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
                        ],
                        if (_isAnalyzing) ...[
                          const SizedBox(height: 24),
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            l10n.nutritionLabelAnalyzing,
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
                        onPressed: () => _pickAndScan(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: Text(l10n.takePhoto),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _pickAndScan(ImageSource.gallery),
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
