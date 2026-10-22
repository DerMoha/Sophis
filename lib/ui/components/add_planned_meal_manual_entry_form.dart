import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/services/planned_meal_factory.dart';
import 'package:sophis/ui/components/nutrition_entry_fields.dart';
import 'package:sophis/ui/components/draft_guard.dart';
import 'package:sophis/utils/number_utils.dart';

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
    extends State<AddPlannedMealManualEntryForm>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _draftKey = GlobalKey<DraftGuardState>();
  bool _isSaving = false;
  String? _saveError;
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
    super.build(context);
    final l10n = AppLocalizations.of(context)!;

    return DraftGuard(
      key: _draftKey,
      controllers: [
        _nameController,
        _caloriesController,
        _proteinController,
        _carbsController,
        _fatController,
      ],
      isSaving: _isSaving,
      child: AbsorbPointer(
        absorbing: _isSaving,
        child: Form(
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
                  return value == null || value.trim().isEmpty
                      ? l10n.required
                      : null;
                },
                caloriesValidator: (value) => _validateNumber(value, l10n),
                macroValidator: (value) {
                  if (value == null || value.isEmpty) return null;
                  return _validateNumber(value, l10n);
                },
              ),
              if (_saveError != null)
                Text(
                  _saveError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(l10n.addMeal),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateNumber(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) return l10n.required;
    final parsed = NumberUtils.parseInput(value);
    if (parsed == null || parsed < 0) {
      return l10n.enterValidPositiveNumber;
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final nutrition = context.read<NutritionProvider>();

    final plannedMeal = PlannedMealFactory.manual(
      date: widget.date,
      meal: widget.mealType,
      name: _nameController.text,
      calories: NumberUtils.parseInput(_caloriesController.text) ?? 0,
      protein: NumberUtils.parseInput(_proteinController.text) ?? 0,
      carbs: NumberUtils.parseInput(_carbsController.text) ?? 0,
      fat: NumberUtils.parseInput(_fatController.text) ?? 0,
    );

    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      await nutrition.addPlannedMeal(plannedMeal);
      if (!mounted) return;
      _draftKey.currentState?.markSaved();
      widget.onSaved();
      HapticFeedback.mediumImpact();
    } catch (_) {
      if (mounted) {
        setState(
          () => _saveError = AppLocalizations.of(context)!.saveEntryFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
