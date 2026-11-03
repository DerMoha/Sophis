import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:sophis/ui/components/draft_guard.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/nutrition_label_draft.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/services/barcode_lookup_service.dart';
import 'package:sophis/services/ai_food_service_factory.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/label_intake_flow.dart';
import 'package:sophis/services/nutrition_label_validator.dart';
import 'package:sophis/services/nutrition_scan_feedback_service.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/ui/components/edit_product_sheet.dart';
import 'package:sophis/ui/components/label_preview_sheet.dart';
import 'package:sophis/ui/components/nutrition_label_draft_sheet.dart';
import 'package:sophis/ui/components/settings/settings_tiles.dart';
import 'package:sophis/ui/screens/nutrition_label_camera_screen.dart';
import 'package:sophis/ui/theme/app_theme.dart';

/// Recovery bottom sheet shown when a barcode product is not found.
/// Offers: search by name, scan nutrition label, enter manually.
class BarcodeNotFoundSheet extends StatefulWidget {
  final String barcode;
  final String? partialName;
  final String? partialBrand;
  final String meal;
  final BarcodeLookupService lookupService;
  final VoidCallback onSearchByName;
  final Function(FoodItem product) onProductResolved;

  const BarcodeNotFoundSheet({
    super.key,
    required this.barcode,
    this.partialName,
    this.partialBrand,
    required this.meal,
    required this.lookupService,
    required this.onSearchByName,
    required this.onProductResolved,
  });

  @override
  State<BarcodeNotFoundSheet> createState() => _BarcodeNotFoundSheetState();
}

class _BarcodeNotFoundSheetState extends State<BarcodeNotFoundSheet> {
  bool _isAnalyzing = false;

  Future<void> _scanNutritionLabel() async {
    final l10n = AppLocalizations.of(context)!;
    final image = await Navigator.push<XFile>(
      context,
      MaterialPageRoute(
        builder: (_) => NutritionLabelCameraScreen(
          title: l10n.nutritionLabelScannerTitle,
          guidance: l10n.nutritionLabelCaptureGuide,
        ),
      ),
    );
    if (image == null || !mounted) return;

    setState(() => _isAnalyzing = true);

    final flow = _buildFlow();
    try {
      final request = LabelIntakeRequest(
        imageFile: File(image.path),
        idGenerator: () => widget.barcode,
        fallbackProductName: widget.partialName ?? l10n.productNotFoundTitle,
        fallbackBrand: widget.partialBrand,
        barcode: widget.barcode,
      );
      // Cloud help is a standing choice in Settings; no per-scan prompt.
      final cloudAssistAllowed = flow.hasCloudAiFallback &&
          context.read<SettingsProvider>().labelCloudHelpEnabled;
      final result = await flow.processImage(
        request,
        allowCloudAssist: cloudAssistAllowed,
      );

      if (!mounted) return;
      switch (result) {
        case Success<LabelIntakeResult>(value: final intake):
          await _onSuccess(intake);
        case Failure<LabelIntakeResult>():
          final draftResult = await flow.processDraftImage(
            request,
            allowCloudAssist: cloudAssistAllowed,
          );
          if (!mounted) return;
          final draft = draftResult.valueOrNull ??
              NutritionLabelDraft(
                productName: widget.partialName,
                brand: widget.partialBrand,
              );
          final confirmed = await showNutritionLabelDraftSheet(
            context: context,
            draft: draft,
            source: draft.analysisSource,
          );
          if (!mounted) return;
          if (confirmed == null) {
            await const NutritionScanFeedbackService().recordOutcome(
              NutritionScanOutcome.rescan,
            );
            return;
          }
          final product = flow.productFromLabel(
            label: confirmed,
            idGenerator: () => widget.barcode,
            fallbackProductName:
                widget.partialName ?? l10n.productNotFoundTitle,
            fallbackBrand: widget.partialBrand,
            barcode: widget.barcode,
          );
          await _onSuccess(
            LabelIntakeResult(
              label: confirmed,
              product: product,
              validation: NutritionLabelValidator.validate(confirmed),
              source: draft.analysisSource,
            ),
            confirmedLabel: confirmed,
            fromPartialDraft: true,
          );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.nutritionLabelNotParsed)),
        );
      }
    } finally {
      flow.dispose();
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  LabelIntakeFlow _buildFlow() {
    final settings = context.read<SettingsProvider>();
    final apiKey = settings.activeAiApiKey;
    final aiService = AiFoodServiceFactory.create(
      provider: settings.aiProvider,
      model: settings.aiModel,
      baseUrl: settings.aiBaseUrl,
    );
    if (apiKey != null && apiKey.isNotEmpty) {
      aiService.initialize(apiKey);
    }
    return LabelIntakeFlow(aiService: aiService);
  }

  Future<void> _onSuccess(
    LabelIntakeResult intake, {
    NutritionLabelResult? confirmedLabel,
    bool fromPartialDraft = false,
  }) async {
    confirmedLabel ??= await showLabelPreviewSheet(
      context: context,
      label: intake.label,
      validation: intake.validation,
      source: intake.source,
    );

    if (!mounted) return;
    if (confirmedLabel == null) {
      await const NutritionScanFeedbackService().recordOutcome(
        NutritionScanOutcome.rescan,
      );
      return;
    }

    await const NutritionScanFeedbackService().record(
      scanned: intake.label,
      confirmed: confirmedLabel,
      outcome: fromPartialDraft
          ? NutritionScanOutcome.partialManualCompletion
          : intake.source != NutritionLabelAnalysisSource.localOcr
              ? NutritionScanOutcome.cloudSuccess
              : NutritionScanOutcome.localSuccess,
    );

    final confirmedProduct = intake.product.copyWith(
      name: confirmedLabel.productName,
      brand: confirmedLabel.brand,
      caloriesPer100g: confirmedLabel.caloriesPer100g,
      proteinPer100g: confirmedLabel.proteinPer100g,
      carbsPer100g: confirmedLabel.carbsPer100g,
      fatPer100g: confirmedLabel.fatPer100g,
      fiberPer100g: confirmedLabel.fiberPer100g,
      nutritionUnit: confirmedLabel.nutritionUnit,
    );

    // A user-confirmed recovery is a durable correction for this barcode, not
    // a short-lived network cache entry. Future scans should use it first.
    await widget.lookupService.saveUserCorrection(
      widget.barcode,
      confirmedProduct,
    );

    if (!mounted) return;
    Navigator.pop(context);
    widget.onProductResolved(confirmedProduct);
  }

  void _enterManually() {
    Navigator.pop(context);
    showDraftBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditProductSheet(
        barcode: widget.barcode,
        initialName: widget.partialName,
        initialBrand: widget.partialBrand,
        showSubmitToOff: true,
        onSave: (product) async {
          await widget.lookupService.saveUserCorrection(
            widget.barcode,
            product,
          );
          widget.onProductResolved(product);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusXS),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color:
                        theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: Icon(
                    Icons.qr_code_2_outlined,
                    color: theme.colorScheme.error,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.productNotFoundTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.partialName != null
                      ? '${widget.partialName} (${widget.barcode})'
                      : widget.barcode,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                NavigationTile(
                  title: l10n.searchByName,
                  icon: Icons.search_outlined,
                  onTap: () {
                    Navigator.pop(context);
                    widget.onSearchByName();
                  },
                ),
                const SizedBox(height: AppTheme.spaceSM2),
                DataActionTile(
                  title: l10n.scanNutritionLabel,
                  icon: Icons.document_scanner_outlined,
                  isLoading: _isAnalyzing,
                  onTap: _scanNutritionLabel,
                ),
                const SizedBox(height: AppTheme.spaceSM2),
                NavigationTile(
                  title: l10n.enterManually,
                  icon: Icons.edit_outlined,
                  onTap: _enterManually,
                ),
              ],
            ),
          ),

          SizedBox(
            height: MediaQuery.of(context).padding.bottom + 24,
          ),
        ],
      ),
    );
  }
}
