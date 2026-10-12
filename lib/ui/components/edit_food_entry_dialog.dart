import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/ui/theme/app_theme.dart';

/// Edits a logged portion while retaining its nutrition and source metadata.
class EditFoodEntryDialog extends StatefulWidget {
  final FoodEntry entry;

  const EditFoodEntryDialog({super.key, required this.entry});

  @override
  State<EditFoodEntryDialog> createState() => _EditFoodEntryDialogState();
}

class _EditFoodEntryDialogState extends State<EditFoodEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _identityKey = GlobalKey();
  final _nutritionSectionKey = GlobalKey();
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final List<TextEditingController> _nutrition;
  late final List<double> _basis;
  late final List<double> _values;
  double _factor = 1;
  bool _manual = false;
  String? _locale;
  final _nutritionKeys = List.generate(5, (_) => GlobalKey());

  double? _parse(String text) => double.tryParse(text.replaceAll(',', '.'));

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _name = TextEditingController(text: entry.name);
    _amount = TextEditingController(text: '${entry.portionAmount ?? 1}');
    _basis = [
      entry.calories,
      entry.protein,
      entry.carbs,
      entry.fat,
      entry.fiber,
    ];
    _values = List.of(_basis);
    _nutrition =
        _values.map((value) => TextEditingController(text: '$value')).toList();
  }

  String _format(double value) => NumberFormat('0.##', _locale).format(value);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (_locale == locale) return;
    _locale = locale;
    for (final controller in [_amount, ..._nutrition]) {
      final value = _parse(controller.text);
      if (value != null && value.isFinite) controller.text = _format(value);
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _amount, ..._nutrition]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _scale(String text) {
    final amount = _parse(text);
    final original = widget.entry.portionAmount ?? 1;
    if (amount == null || !amount.isFinite || amount <= 0 || original <= 0) {
      return;
    }
    final nextFactor = amount / original;
    for (var i = 0; i < _nutrition.length; i++) {
      final value = _parse(_nutrition[i].text);
      if (value != null && value.isFinite && value >= 0) {
        _values[i] = _basis[i] * nextFactor;
        _nutrition[i].text = _format(_values[i]);
      }
    }
    final scaled = widget.entry.scaledBy(nextFactor);
    final previousName = widget.entry.scaledBy(_factor).name;
    if (_name.text == widget.entry.name || _name.text == previousName) {
      _name.text = scaled.name;
    }
    setState(() => _factor = nextFactor);
  }

  void _save() {
    final invalid = _nutrition.indexWhere((controller) {
      final value = _parse(controller.text);
      return value == null || !value.isFinite || value < 0;
    });
    if (invalid >= 0) {
      setState(() => _manual = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _formKey.currentState!.validate();
        final fieldContext = _nutritionKeys[invalid].currentContext;
        if (fieldContext != null) {
          Scrollable.ensureVisible(fieldContext);
        }
      });
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final scaled = widget.entry.scaledBy(_factor);
    Navigator.pop(
      context,
      scaled.copyWith(
        name: _name.text.trim(),
        calories: _values[0],
        protein: _values[1],
        carbs: _values[2],
        fat: _values[3],
        fiber: _values[4],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entry = widget.entry;
    final labels = [
      l10n.calories,
      l10n.protein,
      l10n.carbs,
      l10n.fat,
      l10n.fiber,
    ];
    final hasAmount =
        (entry.portionAmount ?? 0) > 0 && entry.portionUnit != null;
    final theme = Theme.of(context);
    final colors = [
      theme.colorScheme.primary,
      AppTheme.protein,
      AppTheme.carbs,
      AppTheme.fat,
      AppTheme.fiber,
    ];
    final identity = Padding(
      key: _identityKey,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.name, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          TextFormField(
            controller: _name,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.all(14),
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: (value) =>
                (value ?? '').trim().isEmpty ? l10n.name : null,
          ),
          const SizedBox(height: 12),
          Text(l10n.portionSize, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          TextFormField(
            controller: _amount,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.all(14),
              suffixText: hasAmount ? entry.portionUnit!.symbol : '×',
            ),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            onChanged: _scale,
            validator: (text) {
              final value = _parse(text ?? '');
              return value == null || !value.isFinite || value <= 0
                  ? l10n.portionSize
                  : null;
            },
          ),
          const SizedBox(height: 6),
          Text(
            l10n.autoScaleNutritionSubtitle,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
    final nutrition = Padding(
      key: _nutritionSectionKey,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune_outlined),
            title: Text(l10n.nutrition),
            trailing: Icon(
              _manual ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () => setState(() => _manual = !_manual),
          ),
          if (!_manual)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_format(_values.first)} kcal',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      for (var i = 1; i < labels.length; i++)
                        Text(
                          '${labels[i]} ${_format(_values[i])} g',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: colors[i]),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          if (_manual)
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 300 &&
                        MediaQuery.textScalerOf(context).scale(14) <= 20
                    ? 2
                    : 1;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      SizedBox(
                        width: i == 0
                            ? constraints.maxWidth
                            : (constraints.maxWidth - (columns - 1) * 12) /
                                columns,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  i == 0
                                      ? Icons.local_fire_department_outlined
                                      : Icons.circle,
                                  size: i == 0 ? 18 : 8,
                                  color: colors[i],
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    labels[i],
                                    style: theme.textTheme.labelLarge,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              key: _nutritionKeys[i],
                              controller: _nutrition[i],
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.all(14),
                                suffixText: i == 0 ? 'kcal' : 'g',
                                filled: true,
                                fillColor: colors[i].withValues(alpha: 0.08),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              onChanged: (text) {
                                final value = _parse(text);
                                if (value != null &&
                                    value.isFinite &&
                                    value >= 0) {
                                  _values[i] = value;
                                  _basis[i] = value / _factor;
                                }
                                setState(() {});
                              },
                              validator: (text) {
                                final value = _parse(text ?? '');
                                return value == null ||
                                        !value.isFinite ||
                                        value < 0
                                    ? labels[i]
                                    : null;
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 560,
        height: MediaQuery.sizeOf(context).height * 0.9,
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = MediaQuery.viewInsetsOf(context).bottom > 0 ||
                  constraints.maxHeight < 500;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Text(l10n.editEntry,
                        style: theme.textTheme.headlineSmall),
                  ),
                  if (!compact) identity,
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (compact) identity,
                          nutrition,
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: OverflowBar(
                      alignment: MainAxisAlignment.end,
                      spacing: 12,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.cancel),
                        ),
                        FilledButton(
                          onPressed: _save,
                          child: Text(l10n.save),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
