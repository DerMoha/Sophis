import 'package:flutter/material.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/nutrition_label_validator.dart';
import 'package:sophis/ui/theme/app_theme.dart';

/// Shows a modal bottom sheet that previews the values parsed from a nutrition
/// label photo. Returns the confirmed, possibly corrected label, or `null`
/// when the user requests another scan.
Future<NutritionLabelResult?> showLabelPreviewSheet({
  required BuildContext context,
  required NutritionLabelResult label,
  NutritionLabelValidation? validation,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);

  return showModalBottomSheet<NutritionLabelResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (bottomSheetContext) => LabelPreviewSheet(
      label: label,
      validation: validation,
      onLooksGood: (confirmed) => Navigator.pop(bottomSheetContext, confirmed),
      onRescan: () => Navigator.pop(bottomSheetContext),
      l10n: l10n,
      theme: theme,
    ),
  );
}

class LabelPreviewSheet extends StatefulWidget {
  final NutritionLabelResult label;
  final NutritionLabelValidation? validation;
  final ValueChanged<NutritionLabelResult> onLooksGood;
  final VoidCallback onRescan;
  final AppLocalizations l10n;
  final ThemeData theme;

  const LabelPreviewSheet({
    super.key,
    required this.label,
    this.validation,
    required this.onLooksGood,
    required this.onRescan,
    required this.l10n,
    required this.theme,
  });

  @override
  State<LabelPreviewSheet> createState() => _LabelPreviewSheetState();
}

class _LabelPreviewSheetState extends State<LabelPreviewSheet> {
  late final TextEditingController _productName;
  late final TextEditingController _brand;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  late final TextEditingController _fiber;

  @override
  void initState() {
    super.initState();
    _productName = TextEditingController(text: widget.label.productName);
    _brand = TextEditingController(text: widget.label.brand);
    _calories = _controller(widget.label.caloriesPer100g);
    _protein = _controller(widget.label.proteinPer100g);
    _carbs = _controller(widget.label.carbsPer100g);
    _fat = _controller(widget.label.fatPer100g);
    _fiber = _controller(widget.label.fiberPer100g);
  }

  TextEditingController _controller(double value) => TextEditingController(
        text: value.toStringAsFixed(value % 1 == 0 ? 0 : 1),
      );

  double? _value(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  void _confirm() {
    final values =
        [_calories, _protein, _carbs, _fat, _fiber].map(_value).toList();
    if (values.any((value) => value == null || value < 0)) return;
    widget.onLooksGood(
      widget.label.copyWith(
        productName:
            _productName.text.trim().isEmpty ? null : _productName.text.trim(),
        brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
        clearProductName: _productName.text.trim().isEmpty,
        clearBrand: _brand.text.trim().isEmpty,
        caloriesPer100g: values[0],
        proteinPer100g: values[1],
        carbsPer100g: values[2],
        fatPer100g: values[3],
        fiberPer100g: values[4],
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _productName,
      _brand,
      _calories,
      _protein,
      _carbs,
      _fat,
      _fiber,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final l10n = widget.l10n;
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DragHandle(theme: theme),
            _Header(theme: theme, l10n: l10n),
            if (widget.validation case final validation?
                when !validation.isHighConfidence)
              _ConfidenceWarning(theme: theme, issues: validation.issues),
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
                child: _ValueList(
                  theme: theme,
                  l10n: l10n,
                  label: widget.label,
                  productNameController: _productName,
                  brandController: _brand,
                  controllers: [_calories, _protein, _carbs, _fat, _fiber],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _Actions(
              theme: theme,
              l10n: l10n,
              onLooksGood: _confirm,
              onRescan: widget.onRescan,
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceWarning extends StatelessWidget {
  final ThemeData theme;
  final List<String> issues;

  const _ConfidenceWarning({required this.theme, required this.issues});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.tertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              issues.isEmpty
                  ? 'Some values may be uncertain. Please check each field.'
                  : issues.join('\n'),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  final ThemeData theme;
  const _DragHandle({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ThemeData theme;
  final AppLocalizations l10n;
  const _Header({required this.theme, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
    );
  }
}

class _ValueList extends StatelessWidget {
  final ThemeData theme;
  final AppLocalizations l10n;
  final NutritionLabelResult label;
  final TextEditingController productNameController;
  final TextEditingController brandController;
  final List<TextEditingController> controllers;

  const _ValueList({
    required this.theme,
    required this.l10n,
    required this.label,
    required this.productNameController,
    required this.brandController,
    required this.controllers,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: productNameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.foodName,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: brandController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Brand',
          ),
        ),
        const SizedBox(height: 16),
        Divider(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        const SizedBox(height: 12),
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
          controller: controllers[0],
          unit: 'kcal',
          color: theme.colorScheme.primary,
          theme: theme,
        ),
        const SizedBox(height: 10),
        _LabelRow(
          label: l10n.protein,
          controller: controllers[1],
          unit: 'g',
          color: AppTheme.protein,
          theme: theme,
        ),
        const SizedBox(height: 10),
        _LabelRow(
          label: l10n.carbs,
          controller: controllers[2],
          unit: 'g',
          color: AppTheme.carbs,
          theme: theme,
        ),
        const SizedBox(height: 10),
        _LabelRow(
          label: l10n.fat,
          controller: controllers[3],
          unit: 'g',
          color: AppTheme.fat,
          theme: theme,
        ),
        const SizedBox(height: 10),
        _LabelRow(
          label: l10n.fiber,
          controller: controllers[4],
          unit: 'g',
          color: AppTheme.fiber,
          theme: theme,
        ),
        if (label.servingSizeG != null && label.servingSizeG! > 0) ...[
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
                '${l10n.servingInfo}: ${label.servingName ?? l10n.portion} = ${label.servingSizeG!.toStringAsFixed(0)}g',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  final ThemeData theme;
  final AppLocalizations l10n;
  final VoidCallback onLooksGood;
  final VoidCallback onRescan;

  const _Actions({
    required this.theme,
    required this.l10n,
    required this.onLooksGood,
    required this.onRescan,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
    );
  }
}

class _LabelRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String unit;
  final Color color;
  final ThemeData theme;

  const _LabelRow({
    required this.label,
    required this.controller,
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
        SizedBox(
          width: 64,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.end,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
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
