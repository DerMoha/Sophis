import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:gal/gal.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/serving_size.dart';
import 'package:sophis/services/food_entry_factory.dart';
import 'package:sophis/services/gemini_food_service.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/nutrition_label_scanner_service.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/providers/nutrition_provider.dart';
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
          await _showPortionPicker(labelResult);
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
        onAdd: (grams) {
          final entry = FoodEntryFactory.fromFoodItem(
            item: product,
            grams: grams,
            meal: widget.meal,
          );
          final provider = context.read<NutritionProvider>();
          provider.addFoodEntry(entry);
          provider.addRecentFood(product, meal: widget.meal);
          Navigator.pop(context);
        },
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
