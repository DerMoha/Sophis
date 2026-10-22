import 'package:flutter/material.dart';
import 'package:sophis/ui/components/draft_guard.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/ui/components/common/entry_feedback.dart';
import 'package:sophis/utils/number_utils.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/services/food_intake_controller.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/theme/animations.dart';
import 'package:sophis/ui/components/organic_components.dart';
import 'package:sophis/ui/components/settings/settings_tiles.dart';

class AddFoodScreen extends StatefulWidget {
  final String meal;

  const AddFoodScreen({super.key, required this.meal});

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final _draftKey = GlobalKey<DraftGuardState>();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _fiberController = TextEditingController();
  bool _saveAsCustomFood = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    super.dispose();
  }

  String _getMealTitle(BuildContext context, AppLocalizations l10n) {
    final settings = context.read<SettingsProvider>();
    final mealType = settings.getMealType(widget.meal);
    return mealType?.displayName(l10n) ?? l10n.add;
  }

  IconData _getMealIcon(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final mealType = settings.getMealType(widget.meal);
    return mealType?.icon ?? Icons.restaurant_outlined;
  }

  Color? _getMealColor(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final mealType = settings.getMealType(widget.meal);
    return mealType?.color;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final calories = NumberUtils.parseInput(_caloriesController.text) ?? 0;
    final protein = NumberUtils.parseInput(_proteinController.text) ?? 0;
    final carbs = NumberUtils.parseInput(_carbsController.text) ?? 0;
    final fat = NumberUtils.parseInput(_fatController.text) ?? 0;
    final fiber = NumberUtils.parseInput(_fiberController.text) ?? 0;

    setState(() => _isSaving = true);

    final result = await context.read<FoodIntakeController>().logManualEntry(
          name: name,
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          fiber: fiber,
          meal: widget.meal,
          saveAsCustomFood: _saveAsCustomFood,
        );

    if (!mounted) return;

    switch (result) {
      case Success(value: final entry):
        showFoodAddedFeedback(context, entry);
        _draftKey.currentState?.markSaved();
        Navigator.pop(context);
      case Failure():
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.saveEntryFailed),),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return DraftGuard(
      key: _draftKey,
      controllers: [
        _nameController,
        _caloriesController,
        _proteinController,
        _carbsController,
        _fatController,
        _fiberController,
      ],
      hasOtherChanges: _saveAsCustomFood,
      isSaving: _isSaving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.manualEntry),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _isSaving ? null : _save,
                child: Text(
                  l10n.save,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Content
            SliverPadding(
              padding: AppTheme.pagePadding,
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Meal indicator
                        FadeInSlide(
                          index: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusFull),
                            ),
                            child: Builder(
                              builder: (context) {
                                final mealColor = _getMealColor(context) ??
                                    theme.colorScheme.primary;
                                return Row(
                                  children: [
                                    Icon(
                                      _getMealIcon(context),
                                      size: 18,
                                      color: mealColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _getMealTitle(context, l10n),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                          color: mealColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Food name
                        FadeInSlide(
                          index: 1,
                          child: OrganicCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.foodDetails,
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: l10n.foodName,
                                    prefixIcon: const Icon(
                                      Icons.restaurant_outlined,
                                      size: 20,
                                    ),
                                  ),
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                          ? l10n.required
                                          : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _caloriesController,
                                  decoration: InputDecoration(
                                    labelText: l10n.calories,
                                    suffixText: 'kcal',
                                    prefixIcon: const Icon(
                                      Icons.local_fire_department_outlined,
                                      size: 20,
                                    ),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return l10n.required;
                                    }
                                    final value = NumberUtils.parseInput(v);
                                    return value == null || value < 0
                                        ? l10n.enterValidNonNegativeNumber
                                        : null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceLG2),

                        // Macros
                        FadeInSlide(
                          index: 2,
                          child: GlassCard(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.macronutrients,
                                  style: theme.textTheme.titleMedium,
                                ),
                                Text(
                                  l10n.optionalDetailedTracking,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spaceLG2),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: 110,
                                      child: _MacroField(
                                        controller: _proteinController,
                                        label: l10n.protein,
                                        color: AppTheme.protein,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 110,
                                      child: _MacroField(
                                        controller: _carbsController,
                                        label: l10n.carbs,
                                        color: AppTheme.carbs,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 110,
                                      child: _MacroField(
                                        controller: _fatController,
                                        label: l10n.fat,
                                        color: AppTheme.fat,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: 110,
                                  child: _MacroField(
                                    controller: _fiberController,
                                    label: l10n.fiber,
                                    color: AppTheme.fiber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceLG2),

                        // Save as custom food checkbox
                        FadeInSlide(
                          index: 3,
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: CheckboxTile(
                              title: l10n.saveAsCustomFood,
                              subtitle: l10n.saveAsCustomFoodHint,
                              icon: Icons.bookmark_add_outlined,
                              value: _saveAsCustomFood,
                              onChanged: (v) =>
                                  setState(() => _saveAsCustomFood = v),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Save button
                        FadeInSlide(
                          index: 4,
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _save,
                              icon: const Icon(Icons.check, size: 20),
                              label: Text(l10n.save),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Color color;

  const _MacroField({
    required this.controller,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: (text) {
            if (text == null || text.trim().isEmpty) return null;
            final value = NumberUtils.parseInput(text);
            return value == null || value < 0
                ? AppLocalizations.of(context)!.enterValidNonNegativeNumber
                : null;
          },
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: '0',
            suffixText: 'g',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              borderSide: BorderSide(color: color, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
