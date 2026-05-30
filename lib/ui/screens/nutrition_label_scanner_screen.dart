import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:gal/gal.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/serving_size.dart';
import 'package:sophis/services/gemini_food_service.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/nutrition_label_scanner_service.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/providers/settings_provider.dart';
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
  final _scannerService = NutritionLabelScannerService();

  bool _isAnalyzing = false;
  String? _error;
  File? _capturedImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initScanner();
    });
  }

  void _initScanner() {
    final apiKey = context.read<SettingsProvider>().geminiApiKey;
    if (apiKey != null && apiKey.isNotEmpty) {
      final geminiService = GeminiFoodService();
      geminiService.initialize(apiKey);
      _scannerService.setGeminiFallback(geminiService);
    }
  }

  @override
  void dispose() {
    _scannerService.dispose();
    super.dispose();
  }

  Future<void> _pickAndScan(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked == null) return;

      if (source == ImageSource.camera) {
        try {
          await Gal.putImage(picked.path);
        } catch (_) {}
      }

      setState(() {
        _capturedImage = File(picked.path);
        _isAnalyzing = true;
        _error = null;
      });

      final result = await _scannerService.scanLabel(_capturedImage!);

      if (!mounted) return;

      switch (result) {
        case Success<NutritionLabelResult?>(value: final labelResult):
          if (labelResult == null || labelResult.caloriesPer100g == 0) {
            setState(() {
              _isAnalyzing = false;
              _error = AppLocalizations.of(context)!.nutritionLabelNotParsed;
            });
            return;
          }
          await _showLabelPreview(labelResult);
        case Failure<NutritionLabelResult?>(message: final message):
          setState(() {
            _isAnalyzing = false;
            _error = message;
          });
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

  Future<void> _showLabelPreview(NutritionLabelResult result) async {
    if (!mounted) return;
    setState(() => _isAnalyzing = false);

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final shouldProceed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => _NutritionLabelPreview(
        result: result,
        onLooksGood: () => Navigator.pop(bottomSheetContext, true),
        onRescan: () => Navigator.pop(bottomSheetContext, false),
        l10n: l10n,
        theme: theme,
      ),
    );

    if (!mounted) return;

    if (shouldProceed == true) {
      await _showPortionPicker(result);
    } else {
      setState(() {
        _capturedImage = null;
        _error = null;
      });
    }
  }

  Future<void> _showPortionPicker(NutritionLabelResult result) async {
    if (!mounted) return;

    List<ServingSize> servings = [];
    final servingSizeG = result.servingSizeG;
    if (servingSizeG != null && servingSizeG > 0) {
      final servingName = result.servingName ?? 'Portion';
      servings = ServingSize.generateFractions(servingName, servingSizeG);
    }

    final product = FoodItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: result.productName ??
          AppLocalizations.of(context)!.scannedProductName,
      category: 'food',
      caloriesPer100g: result.caloriesPer100g,
      proteinPer100g: result.proteinPer100g,
      carbsPer100g: result.carbsPer100g,
      fatPer100g: result.fatPer100g,
      fiberPer100g: result.fiberPer100g,
      brand: result.brand,
      servings: servings,
    );

    setState(() => _isAnalyzing = false);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PortionPickerSheet(
        item: product,
        meal: widget.meal,
      ),
    );
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

class _NutritionLabelPreview extends StatelessWidget {
  final NutritionLabelResult result;
  final VoidCallback onLooksGood;
  final VoidCallback onRescan;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _NutritionLabelPreview({
    required this.result,
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
                  if (result.productName != null) ...[
                    Text(
                      result.productName!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result.brand != null)
                      Text(
                        result.brand!,
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
