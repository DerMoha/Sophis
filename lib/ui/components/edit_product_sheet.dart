import 'package:flutter/material.dart';
import 'package:sophis/ui/components/draft_guard.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/utils/number_utils.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/services/openfoodfacts_write_service.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/ui/components/modal_sheet.dart';
import 'package:sophis/ui/components/settings/settings_tiles.dart';
import 'package:sophis/ui/theme/app_theme.dart';

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
  final _draftKey = GlobalKey<DraftGuardState>();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  late final TextEditingController _fiberController;
  bool _isSaving = false;
  bool _submitToOff = false;
  late NutritionUnit _nutritionUnit;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProduct;
    _nutritionUnit = p?.nutritionUnit ?? NutritionUnit.gram;
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
    _fiberController = TextEditingController(
      text: p != null && p.fiberPer100g > 0
          ? p.fiberPer100g.toStringAsFixed(1)
          : '',
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
    _fiberController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)!.required;
    }
    return null;
  }

  String? _validateNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)!.required;
    }
    final amount = NumberUtils.parseInput(value);
    if (amount == null || amount < 0) {
      return AppLocalizations.of(context)!.enterValidNonNegativeNumber;
    }
    return null;
  }

  String _normalizeNumber(String value) =>
      value.trim().replaceAll(RegExp(r'[\s\u00a0]'), '').replaceAll(',', '.');

  Widget _buildOffSubmitRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SwitchTile(
      title: l10n.contributeToOff,
      subtitle: l10n.contributeToOffHint,
      icon: Icons.public_outlined,
      value: _submitToOff,
      onChanged: (value) => setState(() => _submitToOff = value),
    );
  }

  Future<void> _save() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final product = FoodItem(
      id: widget.barcode,
      name: _nameController.text.trim(),
      category: widget.existingProduct?.category ?? 'food',
      caloriesPer100g: double.parse(_normalizeNumber(_caloriesController.text)),
      proteinPer100g: double.parse(_normalizeNumber(_proteinController.text)),
      carbsPer100g: double.parse(_normalizeNumber(_carbsController.text)),
      fatPer100g: double.parse(_normalizeNumber(_fatController.text)),
      fiberPer100g:
          double.tryParse(_normalizeNumber(_fiberController.text)) ?? 0,
      nutritionUnit: _nutritionUnit,
      barcode: widget.barcode,
      brand: _brandController.text.trim().isEmpty
          ? null
          : _brandController.text.trim(),
      imageUrl: widget.existingProduct?.imageUrl,
      servings: widget.existingProduct?.servings ?? const [],
    );

    try {
      await widget.onSave(product);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.saveEntryFailed)),
      );
      return;
    }

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
      _draftKey.currentState?.markSaved();
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
    final l10n = AppLocalizations.of(context)!;

    return DraftGuard(
      key: _draftKey,
      controllers: [
        _nameController,
        _brandController,
        _caloriesController,
        _proteinController,
        _carbsController,
        _fatController,
        _fiberController,
      ],
      hasOtherChanges: _submitToOff ||
          _nutritionUnit !=
              (widget.existingProduct?.nutritionUnit ?? NutritionUnit.gram),
      isSaving: _isSaving,
      child: ModalSheetSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ModalSheetHandle(),
            ModalSheetHeader(
              icon: Icons.edit_outlined,
              title: l10n.editProduct,
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: 16,
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

                      DropdownButtonFormField<NutritionUnit>(
                        initialValue: _nutritionUnit,
                        decoration: InputDecoration(
                          labelText: l10n.nutritionBasis,
                          prefixIcon: const Icon(
                            Icons.straighten_outlined,
                            size: 20,
                          ),
                        ),
                        items: NutritionUnit.values
                            .map(
                              (unit) => DropdownMenuItem<NutritionUnit>(
                                value: unit,
                                child: Text(unit.symbol),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _nutritionUnit = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Per 100 unit header
                      Text(
                        l10n.per100Unit(_nutritionUnit.symbol),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceSM2),

                      // Calories
                      TextFormField(
                        controller: _caloriesController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[\d.,]'),
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true,),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.,]'),
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true,),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.,]'),
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true,),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.,]'),
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
                      const SizedBox(height: 12),

                      // Fiber row
                      TextFormField(
                        controller: _fiberController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[\d.,]'),
                          ),
                        ],
                        decoration: InputDecoration(
                          labelText: l10n.fiber,
                          suffixText: 'g',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceSM,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (widget.showSubmitToOff) ...[
                        _buildOffSubmitRow(context),
                        const SizedBox(height: 24),
                      ],

                      // Action buttons
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.end,
                        children: [
                          if (widget.onReset != null)
                            TextButton.icon(
                              onPressed: _isSaving
                                  ? null
                                  : () {
                                      _draftKey.currentState?.markSaved();
                                      widget.onReset?.call();
                                    },
                              icon: const Icon(Icons.restore, size: 18),
                              label: Text(l10n.resetToApiData),
                            ),
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
                            label: Text(l10n.save),
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
      ),
    );
  }
}
