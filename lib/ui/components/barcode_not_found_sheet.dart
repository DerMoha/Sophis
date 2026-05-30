import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/serving_size.dart';
import 'package:sophis/services/barcode_lookup_service.dart';
import 'package:sophis/services/gemini_food_service.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/nutrition_label_scanner_service.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/ui/components/settings/settings_tiles.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/components/edit_product_sheet.dart';

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

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() => _isAnalyzing = true);

    final scannerService = await _getScannerService();
    if (scannerService == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorApiKey)),
        );
      }
      setState(() => _isAnalyzing = false);
      return;
    }

    final analysisResult = await scannerService.scanLabel(File(image.path));

    if (!mounted) return;

    switch (analysisResult) {
      case Success<NutritionLabelResult?>(value: final result):
        if (result == null || result.caloriesPer100g == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.noFoodDetected)),
          );
          setState(() => _isAnalyzing = false);
          return;
        }

        List<ServingSize> servings = [];
        final servingSizeG = result.servingSizeG;
        if (servingSizeG != null && servingSizeG > 0) {
          final servingName = result.servingName ?? 'Portion';
          servings = ServingSize.generateFractions(servingName, servingSizeG);
        }

        final product = FoodItem(
          id: widget.barcode,
          name: result.productName ??
              widget.partialName ??
              l10n.productNotFoundTitle,
          category: 'food',
          caloriesPer100g: result.caloriesPer100g,
          proteinPer100g: result.proteinPer100g,
          carbsPer100g: result.carbsPer100g,
          fatPer100g: result.fatPer100g,
          fiberPer100g: result.fiberPer100g,
          barcode: widget.barcode,
          brand: result.brand ?? widget.partialBrand,
          servings: servings,
        );

        setState(() => _isAnalyzing = false);

        final shouldProceed = await _showLabelPreview(context, result, product);

        if (!mounted) return;

        if (shouldProceed != true) return;

        await widget.lookupService.cacheResult(
          widget.barcode,
          product,
          LookupSource.gemini,
        );

        if (mounted) {
          Navigator.pop(context);
          widget.onProductResolved(product);
        }
      case Failure<NutritionLabelResult?>(message: final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorGeneric(message))),
        );
    }

    if (mounted) setState(() => _isAnalyzing = false);
  }

  Future<NutritionLabelScannerService?> _getScannerService() async {
    final settings = context.read<SettingsProvider>();
    final apiKey = settings.geminiApiKey;

    final scannerService = NutritionLabelScannerService();

    if (apiKey != null && apiKey.isNotEmpty) {
      final geminiService = GeminiFoodService();
      final result = geminiService.initialize(apiKey);
      if (result.isSuccess) {
        scannerService.setGeminiFallback(geminiService);
      }
    }

    return scannerService;
  }

  Future<bool> _showLabelPreview(
    BuildContext context,
    NutritionLabelResult result,
    FoodItem product,
  ) async {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (bottomSheetContext) => _InlineLabelPreview(
            result: result,
            product: product,
            onLooksGood: () => Navigator.pop(bottomSheetContext, true),
            onRescan: () => Navigator.pop(bottomSheetContext, false),
            l10n: l10n,
            theme: theme,
          ),
        ) ??
        false;
  }

  void _enterManually() {
    Navigator.pop(context);
    showModalBottomSheet(
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
                // Search by name
                NavigationTile(
                  title: l10n.searchByName,
                  icon: Icons.search_outlined,
                  onTap: () {
                    Navigator.pop(context);
                    widget.onSearchByName();
                  },
                ),
                const SizedBox(height: AppTheme.spaceSM2),

                // Scan nutrition label
                DataActionTile(
                  title: l10n.scanNutritionLabel,
                  icon: Icons.document_scanner_outlined,
                  isLoading: _isAnalyzing,
                  onTap: _scanNutritionLabel,
                ),
                const SizedBox(height: AppTheme.spaceSM2),

                // Enter manually
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

class _InlineLabelPreview extends StatelessWidget {
  final NutritionLabelResult result;
  final FoodItem product;
  final VoidCallback onLooksGood;
  final VoidCallback onRescan;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _InlineLabelPreview({
    required this.result,
    required this.product,
    required this.onLooksGood,
    required this.onRescan,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusXS),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: Icon(
                    Icons.checklist_outlined,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.nutritionLabelPreview,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.nutritionLabelPreviewSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.name.isNotEmpty) ...[
                    Text(
                      product.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.brand != null && product.brand!.isNotEmpty)
                      Text(
                        product.brand!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Divider(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Center(
                    child: Text(
                      l10n.per100gLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _LabelRow(
                    label: l10n.calories,
                    value: result.caloriesPer100g.toStringAsFixed(0),
                    unit: 'kcal',
                    color: theme.colorScheme.primary,
                    theme: theme,
                  ),
                  const SizedBox(height: 10),
                  _LabelRow(
                    label: l10n.protein,
                    value: result.proteinPer100g.toStringAsFixed(1),
                    unit: 'g',
                    color: AppTheme.protein,
                    theme: theme,
                  ),
                  const SizedBox(height: 10),
                  _LabelRow(
                    label: l10n.carbs,
                    value: result.carbsPer100g.toStringAsFixed(1),
                    unit: 'g',
                    color: AppTheme.carbs,
                    theme: theme,
                  ),
                  const SizedBox(height: 10),
                  _LabelRow(
                    label: l10n.fat,
                    value: result.fatPer100g.toStringAsFixed(1),
                    unit: 'g',
                    color: AppTheme.fat,
                    theme: theme,
                  ),
                  if (result.fiberPer100g > 0) ...[
                    const SizedBox(height: 10),
                    _LabelRow(
                      label: l10n.fiber,
                      value: result.fiberPer100g.toStringAsFixed(1),
                      unit: 'g',
                      color: AppTheme.fiber,
                      theme: theme,
                    ),
                  ],
                  if (result.servingSizeG != null &&
                      result.servingSizeG! > 0) ...[
                    const SizedBox(height: 16),
                    Divider(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.restaurant_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${l10n.servingInfo}: ${result.servingName ?? l10n.portion} = ${result.servingSizeG!.toStringAsFixed(0)}g',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRescan,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(l10n.rescanLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onLooksGood,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(l10n.looksGood),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final ThemeData theme;

  const _LabelRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          unit,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
