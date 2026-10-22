import 'package:flutter/material.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/nutrition_label_validator.dart';
import 'package:sophis/ui/theme/app_theme.dart';

String _validationIssueMessage(
  NutritionLabelIssue issue,
  AppLocalizations l10n,
) {
  return switch (issue) {
    NutritionLabelIssue.caloriesOutOfRange =>
      l10n.nutritionLabelCaloriesRangeWarning,
    NutritionLabelIssue.missingRequiredValue =>
      l10n.nutritionLabelMissingRequiredWarning,
    NutritionLabelIssue.nutrientOutOfRange =>
      l10n.nutritionLabelNutrientRangeWarning,
    NutritionLabelIssue.nutrientTotalTooHigh =>
      l10n.nutritionLabelNutrientTotalWarning,
    NutritionLabelIssue.calorieMacroMismatch =>
      l10n.nutritionLabelCaloriesMismatchWarning,
    NutritionLabelIssue.upperBoundValue => l10n.nutritionLabelUpperBoundWarning,
    NutritionLabelIssue.missingUnitEvidence =>
      l10n.nutritionLabelMissingUnitWarning,
    NutritionLabelIssue.candidateDisagreement =>
      l10n.nutritionLabelCandidateDisagreementWarning,
  };
}

/// Shows a modal bottom sheet that previews the values parsed from a nutrition
/// label photo. Returns the confirmed, possibly corrected label, or `null`
/// when the user requests another scan.
Future<NutritionLabelResult?> showLabelPreviewSheet({
  required BuildContext context,
  required NutritionLabelResult label,
  NutritionLabelValidation? validation,
  NutritionLabelAnalysisSource source = NutritionLabelAnalysisSource.localOcr,
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
      source: source,
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
  final NutritionLabelAnalysisSource source;
  final ValueChanged<NutritionLabelResult> onLooksGood;
  final VoidCallback onRescan;
  final AppLocalizations l10n;
  final ThemeData theme;

  const LabelPreviewSheet({
    super.key,
    required this.label,
    this.validation,
    this.source = NutritionLabelAnalysisSource.localOcr,
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
  bool _hasNutritionEdited = false;

  @override
  void initState() {
    super.initState();
    _productName = TextEditingController(text: widget.label.productName);
    _brand = TextEditingController(text: widget.label.brand);
    _calories =
        _controller(widget.label.caloriesPer100g, NutritionLabelField.calories);
    _protein =
        _controller(widget.label.proteinPer100g, NutritionLabelField.protein);
    _carbs = _controller(widget.label.carbsPer100g, NutritionLabelField.carbs);
    _fat = _controller(widget.label.fatPer100g, NutritionLabelField.fat);
    _fiber = _controller(widget.label.fiberPer100g, NutritionLabelField.fiber);
  }

  TextEditingController _controller(double value, NutritionLabelField field) =>
      TextEditingController(
        text: !widget.label.presentFields.contains(field)
            ? ''
            : '${widget.label.upperBoundFields.contains(field) ? '<' : ''}${value % 1 == 0 ? value.toStringAsFixed(0) : value.toString()}',
      );

  double? _value(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  NutritionLabelResult? _draftLabel() {
    final values = [
      _calories,
      _protein,
      _carbs,
      _fat,
      _fiber,
    ].map(_value).toList();
    if (values.take(4).any((value) => value == null || value < 0)) return null;
    if (_fiber.text.trim().isNotEmpty &&
        (values[4] == null || values[4]! < 0)) {
      return null;
    }
    return widget.label.copyWith(
      productName:
          _productName.text.trim().isEmpty ? null : _productName.text.trim(),
      brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      clearProductName: _productName.text.trim().isEmpty,
      clearBrand: _brand.text.trim().isEmpty,
      caloriesPer100g: values[0],
      proteinPer100g: values[1],
      carbsPer100g: values[2],
      fatPer100g: values[3],
      fiberPer100g: values[4] ?? 0,
      upperBoundFields: const {},
      presentFields: requiredNutritionLabelFields.union(
        {if (values[4] != null) NutritionLabelField.fiber},
      ),
    );
  }

  void _onNutritionChanged() {
    setState(() => _hasNutritionEdited = true);
  }

  void _onIdentityChanged() {
    setState(() {});
  }

  void _confirm() {
    final draft = _draftLabel();
    if (draft == null || !NutritionLabelValidator.validate(draft).isUsable) {
      return;
    }
    widget.onLooksGood(draft);
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
    final draft = _draftLabel();
    final validation = !_hasNutritionEdited && widget.validation != null
        ? widget.validation!
        : draft == null
            ? null
            : NutritionLabelValidator.validate(draft);
    final canConfirm = draft != null &&
        (validation?.isUsable ?? false) &&
        NutritionLabelValidator.validate(draft).isUsable;
    final sourceText = widget.source == NutritionLabelAnalysisSource.gemini
        ? l10n.nutritionLabelAiResult
        : l10n.nutritionLabelLocalResult;
    final analysisText = widget.label.wasServingConverted
        ? '$sourceText • ${l10n.nutritionLabelServingConversion}'
        : sourceText;
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
            _AnalysisSourceNote(
              theme: theme,
              text: analysisText,
              isAi: widget.source == NutritionLabelAnalysisSource.gemini,
            ),
            if (validation == null || !validation.isHighConfidence)
              _ConfidenceWarning(
                theme: theme,
                issues: validation?.issues
                        .map((issue) => _validationIssueMessage(issue, l10n))
                        .toList() ??
                    const [],
                title: l10n.nutritionLabelCheckTitle,
                fallbackMessage: l10n.nutritionLabelUncertain,
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
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
                  onIdentityChanged: _onIdentityChanged,
                  onNutritionChanged: _onNutritionChanged,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _Actions(
              theme: theme,
              l10n: l10n,
              onLooksGood: canConfirm ? _confirm : null,
              onRescan: widget.onRescan,
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
          ],
        ),
      ),
    );
  }
}

class _AnalysisSourceNote extends StatelessWidget {
  final ThemeData theme;
  final String text;
  final bool isAi;

  const _AnalysisSourceNote({
    required this.theme,
    required this.text,
    required this.isAi,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Row(
        children: [
          Icon(
            isAi ? Icons.auto_awesome_outlined : Icons.phone_android,
            size: 17,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.labelMedium)),
        ],
      ),
    );
  }
}

class _ConfidenceWarning extends StatelessWidget {
  final ThemeData theme;
  final List<String> issues;
  final String title;
  final String fallbackMessage;

  const _ConfidenceWarning({
    required this.theme,
    required this.issues,
    required this.title,
    required this.fallbackMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.tertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  issues.isEmpty ? fallbackMessage : issues.join('\n'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
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
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Icon(
              Icons.checklist_outlined,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.nutritionLabelPreview,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  l10n.nutritionLabelPreviewSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
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
  final VoidCallback onIdentityChanged;
  final VoidCallback onNutritionChanged;

  const _ValueList({
    required this.theme,
    required this.l10n,
    required this.label,
    required this.productNameController,
    required this.brandController,
    required this.controllers,
    required this.onIdentityChanged,
    required this.onNutritionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: productNameController,
          onChanged: (_) => onIdentityChanged(),
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: l10n.foodName, isDense: true),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: brandController,
          onChanged: (_) => onIdentityChanged(),
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.productBrand,
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Divider(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        const SizedBox(height: 12),
        Center(
          child: Text(
            l10n.per100Unit(label.nutritionUnit.symbol),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _LabelRow(
          label: l10n.calories,
          controller: controllers[0],
          unit: 'kcal',
          color: theme.colorScheme.primary,
          theme: theme,
          onChanged: onNutritionChanged,
        ),
        const SizedBox(height: 6),
        _LabelRow(
          label: l10n.protein,
          controller: controllers[1],
          unit: 'g',
          color: AppTheme.protein,
          theme: theme,
          onChanged: onNutritionChanged,
        ),
        const SizedBox(height: 6),
        _LabelRow(
          label: l10n.carbs,
          controller: controllers[2],
          unit: 'g',
          color: AppTheme.carbs,
          theme: theme,
          onChanged: onNutritionChanged,
        ),
        const SizedBox(height: 6),
        _LabelRow(
          label: l10n.fat,
          controller: controllers[3],
          unit: 'g',
          color: AppTheme.fat,
          theme: theme,
          onChanged: onNutritionChanged,
        ),
        const SizedBox(height: 6),
        _LabelRow(
          label: l10n.fiber,
          controller: controllers[4],
          unit: 'g',
          color: AppTheme.fiber,
          theme: theme,
          onChanged: onNutritionChanged,
        ),
        if (label.servingSizeG != null && label.servingSizeG! > 0) ...[
          const SizedBox(height: 16),
          Divider(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
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
                '${l10n.servingInfo}: ${label.servingName ?? l10n.portion} = ${label.servingSizeG!.toStringAsFixed(0)}${label.nutritionUnit.symbol}',
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
  final VoidCallback? onLooksGood;
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
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onLooksGood,
              icon: const Icon(Icons.check, size: 18),
              label: Text(l10n.looksGood),
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onRescan,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l10n.rescanLabel),
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
  final VoidCallback onChanged;

  const _LabelRow({
    required this.label,
    required this.controller,
    required this.unit,
    required this.color,
    required this.theme,
    required this.onChanged,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(
          width: 76,
          child: TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.end,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(),
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
