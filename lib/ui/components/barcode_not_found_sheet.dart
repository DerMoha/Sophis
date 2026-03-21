import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/food_item.dart';
import '../../models/serving_size.dart';
import '../../services/barcode_lookup_service.dart';
import '../../services/gemini_food_service.dart';
import '../../services/settings_provider.dart';
import '../theme/app_theme.dart';
import 'edit_product_sheet.dart';

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

    // Check AI availability
    final canRequest = await GeminiFoodService.canMakeRequest();
    if (!canRequest) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noAiRequestsLeft)),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final geminiService = await _getGeminiService();
      if (geminiService == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorApiKey)),
          );
        }
        setState(() => _isAnalyzing = false);
        return;
      }

      final result =
          await geminiService.analyzeNutritionLabel(File(image.path));

      if (result == null || result.caloriesPer100g == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.noFoodDetected)),
          );
        }
        setState(() => _isAnalyzing = false);
        return;
      }

      // Build servings from label data
      List<ServingSize> servings = [];
      if (result.servingSizeG != null && result.servingSizeG! > 0) {
        final servingName = result.servingName ?? 'Portion';
        servings = ServingSize.generateFractions(servingName, result.servingSizeG!);
      }

      final product = FoodItem(
        id: widget.barcode,
        name: result.productName ?? widget.partialName ?? l10n.productNotFoundTitle,
        category: 'food',
        caloriesPer100g: result.caloriesPer100g,
        proteinPer100g: result.proteinPer100g,
        carbsPer100g: result.carbsPer100g,
        fatPer100g: result.fatPer100g,
        barcode: widget.barcode,
        brand: result.brand ?? widget.partialBrand,
        servings: servings,
      );

      // Cache the result
      await widget.lookupService.cacheResult(
        widget.barcode,
        product,
        LookupSource.gemini,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onProductResolved(product);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorGeneric(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<GeminiFoodService?> _getGeminiService() async {
    try {
      final settings = context.read<SettingsProvider>();
      final apiKey = settings.geminiApiKey;
      if (apiKey == null || apiKey.isEmpty) return null;

      final service = GeminiFoodService();
      await service.initialize(apiKey);
      return service;
    } catch (_) {
      return null;
    }
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
                    color: theme.colorScheme.errorContainer
                        .withValues(alpha: 0.3),
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
                _buildOptionTile(
                  context,
                  icon: Icons.search_outlined,
                  title: l10n.searchByName,
                  onTap: () {
                    Navigator.pop(context);
                    widget.onSearchByName();
                  },
                ),
                const SizedBox(height: 12),

                // Scan nutrition label
                _buildOptionTile(
                  context,
                  icon: Icons.document_scanner_outlined,
                  title: l10n.scanNutritionLabel,
                  isLoading: _isAnalyzing,
                  onTap: _isAnalyzing ? null : _scanNutritionLabel,
                ),
                const SizedBox(height: 12),

                // Enter manually
                _buildOptionTile(
                  context,
                  icon: Icons.edit_outlined,
                  title: l10n.enterManually,
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

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(6),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : Icon(icon, size: 18, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
