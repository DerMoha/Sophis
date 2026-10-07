import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/custom_portion.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/nutrition_totals.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/models/portion_selection.dart';
import 'package:sophis/models/serving_size.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/services/barcode_lookup_service.dart';
import 'package:sophis/services/food_intake_controller.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/ui/components/edit_product_sheet.dart';
import 'package:sophis/ui/theme/app_theme.dart';

/// A fast, unit-aware bottom sheet for choosing the amount of a food.
///
/// The sheet deliberately has one logging affordance: the sticky Add button.
/// Selecting a chip or pressing keyboard Done only changes the draft.
class PortionPickerSheet extends StatefulWidget {
  final FoodItem item;
  final String meal;
  final Future<void> Function(FoodEntry entry)? onLogged;
  final String? barcode;
  final BarcodeLookupService? lookupService;
  final Function(FoodItem updatedProduct)? onProductUpdated;

  const PortionPickerSheet({
    super.key,
    required this.item,
    required this.meal,
    this.onLogged,
    this.barcode,
    this.lookupService,
    this.onProductUpdated,
  });

  @override
  State<PortionPickerSheet> createState() => _PortionPickerSheetState();
}

class _PortionPickerSheetState extends State<PortionPickerSheet> {
  late PortionSelection _selection;
  late final TextEditingController _amountController;
  final FocusNode _amountFocusNode = FocusNode();
  bool _isAdding = false;

  NutritionUnit get _unit => widget.item.nutritionUnit;

  String get _productKey => CustomPortion.createProductKey(
        barcode: widget.item.barcode,
        name: widget.item.name,
      );

  List<ServingSize> get _servingOptions => widget.item.servings
      .where((serving) => serving.unit == _unit && serving.selection.isValid)
      .take(12)
      .toList();

  ServingSize? get _baseServing {
    final options = _servingOptions;
    if (options.isEmpty) return null;
    for (final serving in options) {
      if ((serving.multiplier - 1).abs() < 0.001) return serving;
    }
    return options.first;
  }

  @override
  void initState() {
    super.initState();
    _selection = _defaultSelection();
    _amountController = TextEditingController(
      text: _formatNumber(_selection.amount),
    );
  }

  PortionSelection _defaultSelection() {
    final remembered = widget.item.lastUsedPortion;
    if (remembered != null && remembered.unit == _unit && remembered.isValid) {
      return remembered;
    }
    return _baseServing?.selection ??
        PortionSelection(amount: 100, unit: _unit);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    _amountFocusNode.unfocus();
  }

  void _selectPortion(PortionSelection selection) {
    if (!selection.isValid || selection.unit != _unit) return;
    _dismissKeyboard();
    setState(() {
      _selection = selection;
      _amountController.text = _formatNumber(selection.amount);
      _amountController.selection = TextSelection.collapsed(
        offset: _amountController.text.length,
      );
    });
  }

  void _onExactAmountChanged(String value) {
    final amount = _parseLocaleNumber(value);
    setState(() {
      _selection = PortionSelection(
        amount: amount != null && amount > 0 ? amount : 0,
        unit: _unit,
      );
    });
  }

  double? _parseLocaleNumber(String value) {
    var normalized = value.replaceAll(RegExp(r'[\s\u00a0]'), '');
    if (normalized.isEmpty) return null;

    final commaIndex = normalized.lastIndexOf(',');
    final dotIndex = normalized.lastIndexOf('.');
    if (commaIndex >= 0 && dotIndex >= 0) {
      final decimalIndex = commaIndex > dotIndex ? commaIndex : dotIndex;
      final integerPart = normalized.substring(0, decimalIndex);
      final decimalPart = normalized.substring(decimalIndex + 1);
      normalized =
          '${integerPart.replaceAll(RegExp(r'[.,]'), '')}.$decimalPart';
    } else if (commaIndex >= 0) {
      normalized = normalized.replaceAll(',', '.');
    }
    return double.tryParse(normalized);
  }

  NutritionTotals get _calculatedNutrients =>
      widget.item.calculateForSelection(_selection);

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  String _formatLocalizedNumber(BuildContext context, double value) {
    final locale = Localizations.localeOf(context).toString();
    final decimalDigits = (value - value.roundToDouble()).abs() < 0.001
        ? 0
        : ((value * 10) - (value * 10).roundToDouble()).abs() < 0.001
            ? 1
            : 2;
    return NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: decimalDigits,
    ).format(value);
  }

  String _selectionLabel(BuildContext context, PortionSelection selection) {
    final amount = _formatLocalizedNumber(context, selection.amount);
    final canonical = '$amount ${selection.unit.symbol}';
    final label = selection.humanLabel;
    if (label == null || label.trim().isEmpty) return canonical;
    final quantity = selection.labelQuantity;
    final quantityText =
        quantity == null ? '' : '${_formatLocalizedNumber(context, quantity)} ';
    return '$quantityText$label ($canonical)';
  }

  Future<void> _addAndClose() async {
    if (_isAdding || !_selection.isValid) return;
    _dismissKeyboard();
    setState(() => _isAdding = true);

    final result = await context.read<FoodIntakeController>().logFoodItem(
          item: widget.item,
          selection: _selection,
          meal: widget.meal,
        );

    if (!mounted) return;
    switch (result) {
      case Success<FoodEntry>(value: final entry):
        Navigator.pop(context);
        await widget.onLogged?.call(entry);
      case Failure<FoodEntry>(message: final message):
        setState(() => _isAdding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
    }
  }

  void _showSavePresetDialog() {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.saveAsPreset),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.portionName,
            hintText: l10n.portionNameHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final portion = CustomPortion(
                id: const Uuid().v4(),
                productKey: _productKey,
                name: name,
                grams: _selection.amount,
                unit: _selection.unit,
                label: _selection.humanLabel,
                quantity: _selection.labelQuantity,
                createdAt: DateTime.now(),
              );
              await context.read<NutritionProvider>().addCustomPortion(portion);
              if (!mounted || !dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.portionSaved)),
              );
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _openEditSheet() {
    final lookupService = widget.lookupService;
    final barcode = widget.barcode;
    if (lookupService == null || barcode == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditProductSheet(
        barcode: barcode,
        existingProduct: widget.item,
        showSubmitToOff: true,
        onSave: (product) async {
          await lookupService.saveUserCorrection(barcode, product);
          widget.onProductUpdated?.call(product);
        },
        onReset: () async {
          Navigator.pop(context);
          final result = await lookupService.resetCorrection(barcode);
          if (result case Success<BarcodeLookupData>(value: final data)) {
            final product = data.item;
            if (product != null) widget.onProductUpdated?.call(product);
          }
        },
      ),
    );
  }

  Future<void> _renamePortion(
    BuildContext sheetContext,
    CustomPortion portion,
    void Function(void Function()) updateSheet,
  ) async {
    final controller = TextEditingController(text: portion.name);
    final name = await showDialog<String>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.edit),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == portion.name) return;
    if (!mounted) return;

    final provider = context.read<NutritionProvider>();
    await provider.removeCustomPortion(portion.id);
    await provider.addCustomPortion(
      CustomPortion(
        id: portion.id,
        productKey: portion.productKey,
        name: name,
        grams: portion.grams,
        unit: portion.unit,
        label: portion.label,
        quantity: portion.quantity,
        createdAt: portion.createdAt,
      ),
    );
    updateSheet(() {});
  }

  void _showEditPortionsSheet(List<CustomPortion> portions) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, updateSheet) {
          final current = context
              .watch<NutritionProvider>()
              .getCustomPortionsForProduct(_productKey)
              .where((portion) => portion.unit == _unit)
              .toList();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.editPortions,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (current.isEmpty)
                    Text(l10n.customAmount)
                  else
                    ...current.map(
                      (portion) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(portion.name),
                        subtitle:
                            Text(_selectionLabel(context, portion.selection)),
                        leading: const Icon(Icons.bookmark_outline),
                        trailing: Wrap(
                          spacing: 0,
                          children: [
                            IconButton(
                              tooltip: l10n.edit,
                              onPressed: () => _renamePortion(
                                sheetContext,
                                portion,
                                updateSheet,
                              ),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: l10n.delete,
                              onPressed: () async {
                                await context
                                    .read<NutritionProvider>()
                                    .removeCustomPortion(portion.id);
                                updateSheet(() {});
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: Text(l10n.cancel),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final customPortions = context
        .watch<NutritionProvider>()
        .getCustomPortionsForProduct(_productKey)
        .where((portion) => portion.unit == _unit)
        .toList();
    final nutrients = _calculatedNutrients;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const _DragHandle(),
              _ProductHeader(
                item: widget.item,
                selection: _selection,
                nutrients: nutrients,
                onEdit: widget.barcode != null && widget.lookupService != null
                    ? _openEditSheet
                    : null,
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceLG,
                    AppTheme.spaceLG,
                    AppTheme.spaceLG,
                    24,
                  ),
                  children: [
                    if (_servingOptions.isNotEmpty) ...[
                      _SectionTitle(title: l10n.portion),
                      const SizedBox(height: AppTheme.spaceSM2),
                      _ServingChips(
                        servings: _servingOptions,
                        selected: _selection,
                        onSelect: (serving) =>
                            _selectPortion(serving.selection),
                      ),
                      const SizedBox(height: AppTheme.spaceLG),
                    ],
                    if (customPortions.isNotEmpty) ...[
                      _SectionTitle(
                        title: l10n.myPortions,
                        trailing: TextButton(
                          onPressed: () =>
                              _showEditPortionsSheet(customPortions),
                          child: Text(l10n.edit),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceSM2),
                      _SavedPortionChips(
                        portions: customPortions,
                        selected: _selection,
                        onSelect: (portion) =>
                            _selectPortion(portion.selection),
                      ),
                      const SizedBox(height: AppTheme.spaceLG),
                    ],
                    _SectionTitle(title: l10n.customAmount),
                    const SizedBox(height: AppTheme.spaceSM2),
                    _ExactAmountInput(
                      controller: _amountController,
                      focusNode: _amountFocusNode,
                      unit: _unit,
                      onChanged: _onExactAmountChanged,
                      onSubmitted: (_) => _dismissKeyboard(),
                      onSavePreset: _showSavePresetDialog,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.portionPickerKeyboardHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (keyboardHeight > 0)
                      SizedBox(height: keyboardHeight * 0.55),
                  ],
                ),
              ),
              _AddButton(
                selection: _selection,
                calories: nutrients.calories,
                keyboardHeight: keyboardHeight,
                isAdding: _isAdding,
                onAdd: _selection.isValid ? _addAndClose : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
      ),
    );
  }
}

class _ProductHeader extends StatelessWidget {
  final FoodItem item;
  final PortionSelection selection;
  final NutritionTotals nutrients;
  final VoidCallback? onEdit;

  const _ProductHeader({
    required this.item,
    required this.selection,
    required this.nutrients,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final amount = selection.amount == selection.amount.roundToDouble()
        ? selection.amount.toStringAsFixed(0)
        : selection.amount.toStringAsFixed(2);
    final label = selection.humanLabel;
    final portionText = label == null || label.isEmpty
        ? '$amount ${selection.unit.symbol}'
        : '${selection.labelQuantity == null ? '' : '${selection.labelQuantity} '}$label ($amount ${selection.unit.symbol})';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceLG,
        vertical: AppTheme.spaceSM,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            clipBehavior: Clip.antiAlias,
            child: item.imageUrl != null
                ? Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    cacheWidth: 112,
                    cacheHeight: 112,
                    errorBuilder: (_, __, ___) => _placeholder(theme),
                  )
                : _placeholder(theme),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.brand != null && item.brand!.isNotEmpty)
                  Text(
                    item.brand!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$portionText · ${nutrients.calories.toStringAsFixed(0)} kcal',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              tooltip: AppLocalizations.of(context)!.edit,
              icon: Icon(
                Icons.edit_outlined,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder(ThemeData theme) => Center(
        child: Icon(
          Icons.restaurant_outlined,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          size: 24,
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _ServingChips extends StatelessWidget {
  final List<ServingSize> servings;
  final PortionSelection selected;
  final ValueChanged<ServingSize> onSelect;

  const _ServingChips({
    required this.servings,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTheme.spaceSM,
      runSpacing: AppTheme.spaceSM,
      children: servings
          .map(
            (serving) => _ServingChip(
              label: serving.name,
              detail: _canonicalText(context, serving.selection),
              selected: _sameSelection(selected, serving.selection),
              onTap: () => onSelect(serving),
            ),
          )
          .toList(),
    );
  }
}

class _SavedPortionChips extends StatelessWidget {
  final List<CustomPortion> portions;
  final PortionSelection selected;
  final ValueChanged<CustomPortion> onSelect;

  const _SavedPortionChips({
    required this.portions,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTheme.spaceSM,
      runSpacing: AppTheme.spaceSM,
      children: portions
          .map(
            (portion) => _ServingChip(
              label: portion.name,
              detail: _canonicalText(context, portion.selection),
              selected: _sameSelection(selected, portion.selection),
              saved: true,
              onTap: () => onSelect(portion),
            ),
          )
          .toList(),
    );
  }
}

class _ServingChip extends StatelessWidget {
  final String label;
  final String detail;
  final bool selected;
  final bool saved;
  final VoidCallback onTap;

  const _ServingChip({
    required this.label,
    required this.detail,
    required this.selected,
    this.saved = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        saved ? theme.colorScheme.secondary : theme.colorScheme.primary;
    return Material(
      color: selected
          ? color.withValues(alpha: 0.14)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 88),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? color
                  : theme.colorScheme.outline.withValues(alpha: 0.18),
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (saved) ...[
                    Icon(Icons.bookmark_outline, size: 14, color: color),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? color : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExactAmountInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final NutritionUnit unit;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSavePreset;

  const _ExactAmountInput({
    required this.controller,
    required this.focusNode,
    required this.unit,
    required this.onChanged,
    required this.onSubmitted,
    required this.onSavePreset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              suffixText: unit.symbol,
              suffixStyle: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMD,
                vertical: AppTheme.spaceMD,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
            ),
            onChanged: onChanged,
            onSubmitted: onSubmitted,
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filled(
          onPressed: onSavePreset,
          tooltip: l10n.saveAsPreset,
          icon: const Icon(Icons.bookmark_add_outlined),
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            padding: const EdgeInsets.all(AppTheme.spaceMD),
          ),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final PortionSelection selection;
  final double calories;
  final double keyboardHeight;
  final bool isAdding;
  final VoidCallback? onAdd;

  const _AddButton({
    required this.selection,
    required this.calories,
    required this.keyboardHeight,
    required this.isAdding,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final amount = _formatNumber(selection.amount);
    final label = selection.humanLabel;
    final portion = label == null || label.isEmpty
        ? '$amount ${selection.unit.symbol}'
        : '${selection.labelQuantity == null ? '' : '${_formatNumber(selection.labelQuantity!)} '}$label · $amount ${selection.unit.symbol}';
    return AnimatedContainer(
      duration: AppTheme.animFaster,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        keyboardHeight > 0 ? keyboardHeight + 12 : 16,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: keyboardHeight == 0,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isAdding ? null : onAdd,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMD),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
            ),
            child: isAdding
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    l10n.addPortionWithAmount(
                      portion,
                      calories.toStringAsFixed(0),
                    ),
                    style: theme.textTheme.labelLarge,
                  ),
          ),
        ),
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }
}

String _canonicalText(BuildContext context, PortionSelection selection) {
  final locale = Localizations.localeOf(context).toString();
  final amount = NumberFormat.decimalPatternDigits(
    locale: locale,
    decimalDigits: selection.amount == selection.amount.roundToDouble() ? 0 : 2,
  ).format(selection.amount);
  return '$amount ${selection.unit.symbol}';
}

bool _sameSelection(PortionSelection first, PortionSelection second) {
  return first.unit == second.unit &&
      (first.amount - second.amount).abs() < 0.001 &&
      first.humanLabel == second.humanLabel &&
      first.labelQuantity == second.labelQuantity;
}
