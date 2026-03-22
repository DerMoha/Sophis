import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/food_item.dart';
import '../../services/openfoodfacts_write_service.dart';
import '../../services/service_result.dart';
import '../../services/settings_provider.dart';
import '../theme/app_theme.dart';

/// Bottom sheet for editing/creating barcode product nutrition (per 100g).
class EditProductSheet extends StatefulWidget {
  final String barcode;
  final String? initialName;
  final String? initialBrand;
  final FoodItem? existingProduct;
  final Future<void> Function(FoodItem product) onSave;
  final VoidCallback? onReset;
  final bool showSubmitToOff;

  const EditProductSheet({
    super.key,
    required this.barcode,
    this.initialName,
    this.initialBrand,
    this.existingProduct,
    required this.onSave,
    this.onReset,
    this.showSubmitToOff = false,
  });

  @override
  State<EditProductSheet> createState() => _EditProductSheetState();
}

class _EditProductSheetState extends State<EditProductSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  bool _isSaving = false;
  bool _submitToOff = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProduct;
    _nameController = TextEditingController(
      text: p?.name ?? widget.initialName ?? '',
    );
    _brandController = TextEditingController(
      text: p?.brand ?? widget.initialBrand ?? '',
    );
    _caloriesController = TextEditingController(
      text: p != null ? p.caloriesPer100g.toStringAsFixed(0) : '',
    );
    _proteinController = TextEditingController(
      text: p != null ? p.proteinPer100g.toStringAsFixed(1) : '',
    );
    _carbsController = TextEditingController(
      text: p != null ? p.carbsPer100g.toStringAsFixed(1) : '',
    );
    _fatController = TextEditingController(
      text: p != null ? p.fatPer100g.toStringAsFixed(1) : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    return null;
  }

  String? _validateNumber(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    if (double.tryParse(value) == null) return '';
    return null;
  }

  Widget _buildOffSubmitRow(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
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
            child: Icon(
              Icons.public_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.contributeToOff,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  l10n.contributeToOffHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _submitToOff,
            onChanged: (value) => setState(() => _submitToOff = value),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final product = FoodItem(
      id: widget.barcode,
      name: _nameController.text.trim(),
      category: widget.existingProduct?.category ?? 'food',
      caloriesPer100g: double.parse(_caloriesController.text),
      proteinPer100g: double.parse(_proteinController.text),
      carbsPer100g: double.parse(_carbsController.text),
      fatPer100g: double.parse(_fatController.text),
      barcode: widget.barcode,
      brand: _brandController.text.trim().isEmpty
          ? null
          : _brandController.text.trim(),
      imageUrl: widget.existingProduct?.imageUrl,
      servings: widget.existingProduct?.servings ?? const [],
    );

    await widget.onSave(product);

    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.productCorrectionSaved)),
      );
    }

    if (_submitToOff && mounted) {
      await _submitToOpenFoodFacts(product);
    }

    if (mounted) {
      Navigator.pop(context, product);
    }
  }

  Future<void> _submitToOpenFoodFacts(FoodItem product) async {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();

    final writeService = OpenFoodFactsWriteService();
    final result = await writeService.submitProduct(
      product,
      userId: settings.offUserId,
      password: settings.offPassword,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.offSubmitSuccess)),
      );
      return;
    }

    final failure = result as Failure<void>;
    switch (failure.errorType) {
      case ServiceErrorType.authFailed:
        if (settings.hasOffCredentials) {
          await settings.setOffCredentials(null, null);
          final anonResult = await writeService.submitProduct(
            product,
            userId: null,
            password: null,
          );
          if (!mounted) return;
          if (anonResult.isSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.offSubmitSuccess)),
            );
            return;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.offSubmitFailed)),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.offSubmitFailed)),
          );
        }
      case ServiceErrorType.network:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.savedLocallyCouldNotReachOff),
          ),
        );
      case ServiceErrorType.rateLimited:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.offRateLimited)),
        );
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.offSubmitFailed)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppTheme.radiusXS),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.editProduct,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ],
                ),
                IconButton(
                  icon: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                    ),
                    child: const Icon(Icons.close, size: 18),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.name,
                        prefixIcon: const Icon(Icons.restaurant, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMD,
                          vertical: 14,
                        ),
                      ),
                      validator: _validateRequired,
                    ),
                    const SizedBox(height: 16),

                    // Brand
                    TextFormField(
                      controller: _brandController,
                      decoration: const InputDecoration(
                        labelText: 'Brand',
                        prefixIcon: Icon(Icons.storefront, size: 20),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMD,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Per 100g header
                    Text(
                      l10n
                          .per100g('')
                          .replaceAll(': ', '')
                          .replaceAll(' kcal', '')
                          .trim(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSM2),

                    // Calories
                    TextFormField(
                      controller: _caloriesController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,1}'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.calories,
                        prefixIcon: const Icon(
                          Icons.local_fire_department_outlined,
                          size: 20,
                        ),
                        suffixText: 'kcal',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMD,
                          vertical: 14,
                        ),
                      ),
                      validator: _validateNumber,
                    ),
                    const SizedBox(height: 16),

                    // Macros row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _proteinController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,1}'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.protein,
                              suffixText: 'g',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spaceSM,
                                vertical: 14,
                              ),
                            ),
                            validator: _validateNumber,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _carbsController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,1}'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.carbs,
                              suffixText: 'g',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spaceSM,
                                vertical: 14,
                              ),
                            ),
                            validator: _validateNumber,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _fatController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,1}'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.fat,
                              suffixText: 'g',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spaceSM,
                                vertical: 14,
                              ),
                            ),
                            validator: _validateNumber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (widget.showSubmitToOff) ...[
                      _buildOffSubmitRow(context),
                      const SizedBox(height: 24),
                    ],

                    // Action buttons
                    Row(
                      children: [
                        if (widget.onReset != null)
                          TextButton.icon(
                            onPressed: widget.onReset,
                            icon: const Icon(Icons.restore, size: 18),
                            label: Text(l10n.resetToApiData),
                          ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check, size: 18),
                          label: Text(l10n.saveCorrection),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spaceLG,
                              vertical: AppTheme.spaceSM,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
