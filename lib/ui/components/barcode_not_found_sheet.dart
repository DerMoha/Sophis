import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/services/barcode_lookup_service.dart';
import 'package:sophis/services/gemini_food_service.dart';
import 'package:sophis/services/label_intake_flow.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/ui/components/edit_product_sheet.dart';
import 'package:sophis/ui/components/label_preview_sheet.dart';
import 'package:sophis/ui/components/settings/settings_tiles.dart';
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
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() => _isAnalyzing = true);

    final flow = _buildFlow();
    if (!flow.hasGeminiFallback) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorApiKey)),
        );
      }
      setState(() => _isAnalyzing = false);
      return;
    }

    final result = await flow.processImage(
      LabelIntakeRequest(
        imageFile: File(image.path),
        idGenerator: () => widget.barcode,
        fallbackProductName:
            widget.partialName ?? l10n.productNotFoundTitle,
        fallbackBrand: widget.partialBrand,
        barcode: widget.barcode,
      ),
    );

    if (!mounted) return;
    flow.dispose();

    switch (result) {
      case Success<LabelIntakeResult>(value: final intake):
        await _onSuccess(intake);
      case Failure<LabelIntakeResult>(message: final message):
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorGeneric(message))),
          );
        }
    }

    if (mounted) setState(() => _isAnalyzing = false);
  }

  LabelIntakeFlow _buildFlow() {
    final apiKey = context.read<SettingsProvider>().geminiApiKey;
    final gemini = GeminiFoodService();
    if (apiKey != null && apiKey.isNotEmpty) {
      gemini.initialize(apiKey);
    }
    return LabelIntakeFlow(gemini: gemini);
  }

  Future<void> _onSuccess(LabelIntakeResult intake) async {
    final confirmed = await showLabelPreviewSheet(
      context: context,
      label: intake.label,
    );

    if (!mounted) return;
    if (!confirmed) return;

    await widget.lookupService.cacheResult(
      widget.barcode,
      intake.product,
      LookupSource.gemini,
    );

    if (!mounted) return;
    Navigator.pop(context);
    widget.onProductResolved(intake.product);
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
