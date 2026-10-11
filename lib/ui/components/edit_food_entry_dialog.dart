import 'package:flutter/material.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/nutrition_unit.dart';

/// Edits a logged portion while retaining its nutrition and source metadata.
class EditFoodEntryDialog extends StatefulWidget {
  final FoodEntry entry;

  const EditFoodEntryDialog({super.key, required this.entry});

  @override
  State<EditFoodEntryDialog> createState() => _EditFoodEntryDialogState();
}

class _EditFoodEntryDialogState extends State<EditFoodEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final List<TextEditingController> _nutrition;
  double _factor = 1;

  double? _parse(String text) => double.tryParse(text.replaceAll(',', '.'));

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _name = TextEditingController(text: entry.name);
    _amount = TextEditingController(text: '${entry.portionAmount ?? 1}');
    _nutrition = [
      entry.calories,
      entry.protein,
      entry.carbs,
      entry.fat,
      entry.fiber,
    ].map((value) => TextEditingController(text: '$value')).toList();
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
    for (final controller in _nutrition) {
      final value = _parse(controller.text);
      if (value != null) {
        controller.text = (value / _factor * nextFactor).toStringAsFixed(2);
      }
    }
    final scaled = widget.entry.scaledBy(nextFactor);
    final previousName = widget.entry.scaledBy(_factor).name;
    if (_name.text == widget.entry.name || _name.text == previousName) {
      _name.text = scaled.name;
    }
    setState(() => _factor = nextFactor);
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
    return AlertDialog(
      title: Text(l10n.editEntry),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: l10n.name),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? l10n.name : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amount,
                  decoration: InputDecoration(
                    labelText: l10n.portionSize,
                    suffixText: hasAmount ? entry.portionUnit!.symbol : '×',
                    helperText: l10n.autoScaleNutritionSubtitle,
                    helperMaxLines: 2,
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
                const SizedBox(height: 16),
                Text(
                  '${_nutrition.first.text} kcal',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ExpansionTile(
                  maintainState: true,
                  tilePadding: EdgeInsets.zero,
                  title: Text(l10n.nutrition),
                  children: [
                    for (var i = 0; i < _nutrition.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              labels[i],
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _nutrition[i],
                              decoration: InputDecoration(
                                suffixText: i == 0 ? 'kcal' : 'g',
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              onChanged: (_) => setState(() {}),
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
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final scaled = entry.scaledBy(_factor);
            Navigator.pop(
              context,
              scaled.copyWith(
                name: _name.text.trim(),
                calories: _parse(_nutrition[0].text),
                protein: _parse(_nutrition[1].text),
                carbs: _parse(_nutrition[2].text),
                fat: _parse(_nutrition[3].text),
                fiber: _parse(_nutrition[4].text),
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
