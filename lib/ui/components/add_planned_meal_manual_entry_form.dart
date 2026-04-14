import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/services/nutrition_provider.dart';
import 'package:sophis/services/planned_meal_factory.dart';
import 'package:sophis/ui/components/nutrition_entry_fields.dart';

class AddPlannedMealManualEntryForm extends StatefulWidget {
  final DateTime date;
  final String mealType;
  final VoidCallback onSaved;

  const AddPlannedMealManualEntryForm({
    super.key,
    required this.date,
    required this.mealType,
    required this.onSaved,
  });

  @override
  State<AddPlannedMealManualEntryForm> createState() =>
      _AddPlannedMealManualEntryFormState();
}

class _AddPlannedMealManualEntryFormState
    extends State<AddPlannedMealManualEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          NutritionEntryFields(
            nameController: _nameController,
            caloriesController: _caloriesController,
            proteinController: _proteinController,
            carbsController: _carbsController,
            fatController: _fatController,
            nameLabel: l10n.foodName,
            nameTextCapitalization: TextCapitalization.sentences,
            nameValidator: (value) {
              return value == null || value.isEmpty ? l10n.required : null;
            },
            caloriesValidator: (value) => _validateNumber(value, l10n),
            macroValidator: (value) {
              if (value == null || value.isEmpty) return null;
              return _validateNumber(value, l10n);
            },
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _submit,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(l10n.addMeal),
            ),
          ),
        ],
      ),
    );
  }

  String? _validateNumber(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) return l10n.required;
    final parsed = double.tryParse(value);
    if (parsed == null || parsed < 0) {
      return l10n.enterValidPositiveNumber;
    }
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final nutrition = context.read<NutritionProvider>();

    final plannedMeal = PlannedMealFactory.manual(
      date: widget.date,
      meal: widget.mealType,
      name: _nameController.text,
      calories: double.tryParse(_caloriesController.text) ?? 0,
      protein: double.tryParse(_proteinController.text) ?? 0,
      carbs: double.tryParse(_carbsController.text) ?? 0,
      fat: double.tryParse(_fatController.text) ?? 0,
    );

    nutrition.addPlannedMeal(plannedMeal);
    widget.onSaved();
    HapticFeedback.mediumImpact();
  }
}
