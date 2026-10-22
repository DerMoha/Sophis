import 'package:flutter/material.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/nutrition_label_draft.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/nutrition_label_validator.dart';
import 'package:sophis/ui/theme/app_theme.dart';

/// Reviews a partial label read and returns the completed draft as a nullable
/// [NutritionLabelResult]. Fiber may be left blank and is treated as zero;
/// calories, protein, carbs, and fat are required before confirmation.
Future<NutritionLabelResult?> showNutritionLabelDraftSheet({
  required BuildContext context,
  required NutritionLabelDraft draft,
  NutritionLabelAnalysisSource source = NutritionLabelAnalysisSource.localOcr,
}) async {
  return showModalBottomSheet<NutritionLabelResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _NutritionLabelDraftSheet(draft: draft, source: source),
  );
}

class _NutritionLabelDraftSheet extends StatefulWidget {
  final NutritionLabelDraft draft;
  final NutritionLabelAnalysisSource source;

  const _NutritionLabelDraftSheet({
    required this.draft,
    required this.source,
  });

  @override
  State<_NutritionLabelDraftSheet> createState() =>
      _NutritionLabelDraftSheetState();
}

class _NutritionLabelDraftSheetState extends State<_NutritionLabelDraftSheet> {
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  late final TextEditingController _fiber;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.draft.productName ?? '');
    _brand = TextEditingController(text: widget.draft.brand ?? '');
    _calories = _numberController(
      widget.draft.caloriesPer100,
      NutritionLabelField.calories,
    );
    _protein = _numberController(
      widget.draft.proteinPer100,
      NutritionLabelField.protein,
    );
    _carbs =
        _numberController(widget.draft.carbsPer100, NutritionLabelField.carbs);
    _fat = _numberController(widget.draft.fatPer100, NutritionLabelField.fat);
    _fiber =
        _numberController(widget.draft.fiberPer100, NutritionLabelField.fiber);
  }

  TextEditingController _numberController(
    double? value,
    NutritionLabelField field,
  ) =>
      TextEditingController(
        text: value == null
            ? ''
            : '${widget.draft.upperBoundFields.contains(field) ? '<' : ''}${_format(value)}',
      );

  String _format(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  double? _number(TextEditingController controller) {
    var value = controller.text.trim().replaceAll(RegExp(r'[\s\u00a0]'), '');
    if (value.contains(',') && value.contains('.')) {
      final comma = value.lastIndexOf(',');
      final dot = value.lastIndexOf('.');
      final decimal = comma > dot ? comma : dot;
      value =
          '${value.substring(0, decimal).replaceAll(RegExp(r'[.,]'), '')}.${value.substring(decimal + 1)}';
    } else {
      value = value.replaceAll(',', '.');
    }
    return double.tryParse(value);
  }

  NutritionLabelDraft? _currentDraft() {
    final values =
        [_calories, _protein, _carbs, _fat, _fiber].map(_number).toList();
    if (_fiber.text.trim().isNotEmpty && values[4] == null) return null;
    if (values.take(4).any((value) => value == null || value < 0)) {
      return null;
    }
    return NutritionLabelDraft(
      productName: _name.text.trim().isEmpty ? null : _name.text.trim(),
      brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      caloriesPer100: values[0],
      proteinPer100: values[1],
      carbsPer100: values[2],
      fatPer100: values[3],
      fiberPer100: values[4],
      nutritionUnit: widget.draft.nutritionUnit,
      servingAmount: widget.draft.servingAmount,
      servingName: widget.draft.servingName,
      wasServingConverted: widget.draft.wasServingConverted,
      analysisSource: widget.draft.analysisSource,
    );
  }

  void _confirm() {
    final current = _currentDraft();
    final label = current?.toResult();
    if (label == null || !NutritionLabelValidator.validate(label).isUsable) {
      return;
    }
    Navigator.pop(context, label);
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final current = _currentDraft();
    final label = current?.toResult();
    final canConfirm =
        label != null && NutritionLabelValidator.validate(label).isUsable;
    final sourceText = widget.source == NutritionLabelAnalysisSource.gemini
        ? l10n.nutritionLabelAiResult
        : l10n.nutritionLabelLocalResult;
    final analysisText = widget.draft.wasServingConverted
        ? '$sourceText • ${l10n.nutritionLabelServingConversion}'
        : sourceText;

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.nutritionLabelPreview,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(l10n.nutritionLabelUncertain),
            if (widget.draft.upperBoundFields.isNotEmpty)
              Text(l10n.nutritionLabelUpperBoundWarning),
            const SizedBox(height: 8),
            Text(
              analysisText,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.foodName),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _brand,
              decoration: InputDecoration(labelText: l10n.productBrand),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.per100Unit(widget.draft.nutritionUnit.symbol),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _DraftField(
              label: l10n.calories,
              unit: 'kcal',
              controller: _calories,
              onChanged: () => setState(() {}),
            ),
            _DraftField(
              label: l10n.protein,
              unit: 'g',
              controller: _protein,
              onChanged: () => setState(() {}),
            ),
            _DraftField(
              label: l10n.carbs,
              unit: 'g',
              controller: _carbs,
              onChanged: () => setState(() {}),
            ),
            _DraftField(
              label: l10n.fat,
              unit: 'g',
              controller: _fat,
              onChanged: () => setState(() {}),
            ),
            _DraftField(
              label: l10n.fiber,
              unit: 'g · optional',
              controller: _fiber,
              onChanged: () => setState(() {}),
            ),
            if (!canConfirm) ...[
              const SizedBox(height: 8),
              Text(
                l10n.nutritionLabelDraftRequired,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: canConfirm ? _confirm : null,
              icon: const Icon(Icons.check),
              label: Text(l10n.looksGood),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.rescanLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftField extends StatelessWidget {
  final String label;
  final String unit;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _DraftField({
    required this.label,
    required this.unit,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          SizedBox(
            width: 92,
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.end,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(width: 58, child: Text(unit)),
        ],
      ),
    );
  }
}
