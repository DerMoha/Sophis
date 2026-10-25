import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/nutrition_label_draft.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/models/portion_selection.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/services/food_intake_controller.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/nutrition_label_validator.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/ui/components/common/entry_feedback.dart';
import 'package:sophis/ui/theme/app_theme.dart';

enum LabelReviewOutcome { logged, rescan }

/// One screen between a label scan and the diary: check the values, pick the
/// portion, log. Logging also keeps the product as a reusable custom food.
class LabelReviewScreen extends StatefulWidget {
  final NutritionLabelDraft draft;
  final String meal;

  /// True when the reader was unsure; highlights the values to check.
  final bool needsReview;

  /// Builds the stored product (id, servings) from the confirmed values.
  final FoodItem Function(NutritionLabelResult label) buildProduct;

  /// Called after logging, e.g. to record scan accuracy feedback.
  final Future<void> Function(NutritionLabelResult confirmed)? onLogged;

  const LabelReviewScreen({
    super.key,
    required this.draft,
    required this.meal,
    required this.buildProduct,
    this.needsReview = false,
    this.onLogged,
  });

  @override
  State<LabelReviewScreen> createState() => _LabelReviewScreenState();
}

class _LabelReviewScreenState extends State<LabelReviewScreen> {
  late final TextEditingController _name;
  late final Map<NutritionLabelField, TextEditingController> _values;
  late final TextEditingController _amount;
  late NutritionUnit _unit;
  bool _isLogging = false;
  String _decimalSeparator = '.';
  bool _localized = false;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _name = TextEditingController(text: draft.productName ?? '');
    _unit = draft.nutritionUnit;
    _values = {
      NutritionLabelField.calories: _controller(
        draft.caloriesPer100,
        NutritionLabelField.calories,
      ),
      NutritionLabelField.protein: _controller(
        draft.proteinPer100,
        NutritionLabelField.protein,
      ),
      NutritionLabelField.carbs: _controller(
        draft.carbsPer100,
        NutritionLabelField.carbs,
      ),
      NutritionLabelField.fat:
          _controller(draft.fatPer100, NutritionLabelField.fat),
      NutritionLabelField.fiber: _controller(
        draft.fiberPer100,
        NutritionLabelField.fiber,
      ),
    };
    _amount = TextEditingController(
      text: _format(draft.servingAmount ?? 100),
    );
  }

  TextEditingController _controller(
    double? value,
    NutritionLabelField field,
  ) {
    if (value == null) return TextEditingController();
    final qualifier = widget.draft.upperBoundFields.contains(field) ? '<' : '';
    return TextEditingController(text: '$qualifier${_format(value)}');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_localized) return;
    _localized = true;
    // Show prefilled numbers the way the user types them (0,2 in German).
    _decimalSeparator =
        NumberFormat.decimalPattern(Localizations.localeOf(context).toString())
            .symbols
            .DECIMAL_SEP;
    for (final controller in [..._values.values, _amount]) {
      controller.text = _localize(controller.text);
    }
  }

  String _localize(String text) =>
      _decimalSeparator == '.' ? text : text.replaceAll('.', _decimalSeparator);

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    for (final controller in _values.values) {
      controller.dispose();
    }
    super.dispose();
  }

  static String _format(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  static double? _parse(String text) {
    var value = text.trim().replaceAll(RegExp(r'[\s ]'), '');
    if (value.isEmpty) return null;
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

  double? _value(NutritionLabelField field) => _parse(_values[field]!.text);

  bool _isOptional(NutritionLabelField field) =>
      field == NutritionLabelField.fiber;

  /// The confirmed label, or null while a required value is missing.
  NutritionLabelResult? get _label {
    final fiberText = _values[NutritionLabelField.fiber]!.text.trim();
    final fiber = _value(NutritionLabelField.fiber);
    if (fiberText.isNotEmpty && fiber == null) return null;
    final calories = _value(NutritionLabelField.calories);
    final protein = _value(NutritionLabelField.protein);
    final carbs = _value(NutritionLabelField.carbs);
    final fat = _value(NutritionLabelField.fat);
    if ([calories, protein, carbs, fat].any((v) => v == null || v < 0)) {
      return null;
    }
    final name = _name.text.trim();
    final label = NutritionLabelResult(
      productName: name.isEmpty ? null : name,
      brand: widget.draft.brand,
      caloriesPer100g: calories!,
      proteinPer100g: protein!,
      carbsPer100g: carbs!,
      fatPer100g: fat!,
      fiberPer100g: fiber ?? 0,
      nutritionUnit: _unit,
      servingSizeG: widget.draft.servingAmount,
      servingName: widget.draft.servingName,
      wasServingConverted: widget.draft.wasServingConverted,
      presentFields: {
        ...requiredNutritionLabelFields,
        if (fiber != null) NutritionLabelField.fiber,
      },
    );
    return NutritionLabelValidator.validate(label).isUsable ? label : null;
  }

  PortionSelection get _selection =>
      PortionSelection(amount: _parse(_amount.text) ?? 0, unit: _unit);

  Future<void> _log() async {
    final label = _label;
    final selection = _selection;
    if (_isLogging || label == null || !selection.isValid) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLogging = true);

    final nutrition = context.read<NutritionProvider>();
    var product = widget.buildProduct(label);
    // Reuse an identical earlier scan instead of piling up duplicates.
    final existing =
        nutrition.customFoods.where((f) => _isSameProduct(f, product));
    if (existing.isNotEmpty) {
      product = existing.first;
    } else {
      await nutrition.addCustomFood(product);
    }
    if (!mounted) return;

    final result = await context.read<FoodIntakeController>().logFoodItem(
          item: product,
          selection: selection,
          meal: widget.meal,
        );
    if (!mounted) return;
    switch (result) {
      case Success<FoodEntry>(value: final entry):
        await widget.onLogged?.call(label);
        if (!mounted) return;
        showFoodAddedFeedback(context, entry);
        Navigator.pop(context, LabelReviewOutcome.logged);
      case Failure<FoodEntry>():
        setState(() => _isLogging = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.saveEntryFailed),
          ),
        );
    }
  }

  static bool _isSameProduct(FoodItem a, FoodItem b) {
    return a.name.trim().toLowerCase() == b.name.trim().toLowerCase() &&
        (a.brand ?? '').trim().toLowerCase() ==
            (b.brand ?? '').trim().toLowerCase() &&
        a.nutritionUnit == b.nutritionUnit &&
        a.caloriesPer100g == b.caloriesPer100g &&
        a.proteinPer100g == b.proteinPer100g &&
        a.carbsPer100g == b.carbsPer100g &&
        a.fatPer100g == b.fatPer100g;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final label = _label;
    final selection = _selection;
    final canLog = label != null && selection.isValid && !_isLogging;
    final portionCalories =
        label == null ? null : label.caloriesPer100g * selection.amount / 100;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.nutritionLabelPreview),
        actions: [
          IconButton(
            tooltip: l10n.rescanLabel,
            onPressed: _isLogging
                ? null
                : () => Navigator.pop(context, LabelReviewOutcome.rescan),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  if (widget.needsReview ||
                      widget.draft.upperBoundFields.isNotEmpty)
                    _ReviewBanner(
                      text: widget.draft.upperBoundFields.isNotEmpty
                          ? l10n.nutritionLabelUpperBoundWarning
                          : l10n.nutritionLabelUncertain,
                    ),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: l10n.foodName),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.per100Unit(_unit.symbol),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SegmentedButton<NutritionUnit>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: NutritionUnit.gram,
                            label: Text('g'),
                          ),
                          ButtonSegment(
                            value: NutritionUnit.milliliter,
                            label: Text('ml'),
                          ),
                        ],
                        selected: {_unit},
                        onSelectionChanged: (units) =>
                            setState(() => _unit = units.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final field in NutritionLabelField.values)
                    _ValueRow(
                      label: switch (field) {
                        NutritionLabelField.calories => l10n.calories,
                        NutritionLabelField.protein => l10n.protein,
                        NutritionLabelField.carbs => l10n.carbs,
                        NutritionLabelField.fat => l10n.fat,
                        NutritionLabelField.fiber => l10n.fiber,
                      },
                      unit:
                          field == NutritionLabelField.calories ? 'kcal' : 'g',
                      controller: _values[field]!,
                      errorText: _errorFor(field, l10n),
                      onChanged: () => setState(() {}),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.portion,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _PortionRow(
                    controller: _amount,
                    unit: _unit,
                    servingAmount: widget.draft.servingAmount,
                    servingName: widget.draft.servingName,
                    onChanged: () => setState(() {}),
                    format: (value) => _localize(_format(value)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: canLog ? _log : null,
                  child: _isLogging
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          portionCalories == null
                              ? l10n.nutritionLabelDraftRequired
                              : l10n.addPortionWithAmount(
                                  '${_localize(_format(selection.amount))} ${_unit.symbol}',
                                  portionCalories.toStringAsFixed(0),
                                ),
                          textAlign: TextAlign.center,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _errorFor(NutritionLabelField field, AppLocalizations l10n) {
    final text = _values[field]!.text.trim();
    if (text.isEmpty) {
      return _isOptional(field) ? null : l10n.labelReviewRequired;
    }
    if (_parse(text) == null) return l10n.labelReviewEnterEstimate;
    return null;
  }
}

class _ReviewBanner extends StatelessWidget {
  final String text;

  const _ReviewBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppTheme.warning),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String label;
  final String unit;
  final TextEditingController controller;
  final String? errorText;
  final VoidCallback onChanged;

  const _ValueRow({
    required this.label,
    required this.unit,
    required this.controller,
    required this.errorText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(label, style: theme.textTheme.bodyLarge),
            ),
          ),
          SizedBox(
            width: 132,
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.end,
              decoration: InputDecoration(
                isDense: true,
                suffixText: unit,
                errorText: errorText,
                errorMaxLines: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PortionRow extends StatelessWidget {
  final TextEditingController controller;
  final NutritionUnit unit;
  final double? servingAmount;
  final String? servingName;
  final VoidCallback onChanged;
  final String Function(double value) format;

  const _PortionRow({
    required this.controller,
    required this.unit,
    required this.servingAmount,
    required this.servingName,
    required this.onChanged,
    required this.format,
  });

  void _set(double amount) {
    controller.text = format(amount);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final serving = servingAmount;
    final presets = <(String, double)>[
      if (serving != null && serving > 0 && serving != 100)
        (
          servingName == null || servingName!.trim().isEmpty
              ? '${format(serving)} ${unit.symbol}'
              : '$servingName · ${format(serving)} ${unit.symbol}',
          serving,
        ),
      ('100 ${unit.symbol}', 100),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: unit.symbol),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, amount) in presets)
              ActionChip(label: Text(label), onPressed: () => _set(amount)),
          ],
        ),
      ],
    );
  }
}
