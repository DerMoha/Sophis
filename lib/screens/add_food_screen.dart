import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/food_entry.dart';
import '../models/food_item.dart';
import '../services/nutrition_provider.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../widgets/organic_components.dart';

class AddFoodScreen extends StatefulWidget {
  final String meal;

  const AddFoodScreen({super.key, required this.meal});

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  bool _saveAsCustomFood = false;

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  String _getMealTitle(BuildContext context, AppLocalizations l10n) {
    final settings = context.read<SettingsProvider>();
    final mealType = settings.getMealType(widget.meal);
    return mealType?.name ?? l10n.add;
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
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<NutritionProvider>();
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final calories = double.tryParse(_caloriesController.text) ?? 0;
    final protein = double.tryParse(_proteinController.text) ?? 0;
    final carbs = double.tryParse(_carbsController.text) ?? 0;
    final fat = double.tryParse(_fatController.text) ?? 0;

    final entry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      timestamp: DateTime.now(),
      meal: widget.meal,
    );

    await provider.addFoodEntry(entry);

    // Also save as custom food if checkbox is checked
    if (_saveAsCustomFood) {
      final customFood = FoodItem(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        category: 'custom',
        caloriesPer100g: calories,
        proteinPer100g: protein,
        carbsPer100g: carbs,
        fatPer100g: fat,
      );
      await provider.addCustomFood(customFood);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.customFoodSaved)),
        );
      }
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 100,
            floating: true,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            centerTitle: false,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                l10n.manualEntry,
                style: theme.textTheme.headlineMedium,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: _save,
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

          // Content
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
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
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          child: Builder(
                            builder: (context) {
                              final mealColor = _getMealColor(context) ?? theme.colorScheme.primary;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getMealIcon(context),
                                    size: 18,
                                    color: mealColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _getMealTitle(context, l10n),
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: mealColor,
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
                                  prefixIcon:
                                      const Icon(Icons.restaurant_outlined, size: 20),
                                ),
                                textCapitalization: TextCapitalization.sentences,
                                validator: (v) =>
                                    v == null || v.isEmpty ? l10n.required : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _caloriesController,
                                decoration: InputDecoration(
                                  labelText: l10n.calories,
                                  suffixText: 'kcal',
                                  prefixIcon: const Icon(
                                      Icons.local_fire_department_outlined,
                                      size: 20),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) =>
                                    v == null || v.isEmpty ? l10n.required : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

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
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: _MacroField(
                                      controller: _proteinController,
                                      label: l10n.protein,
                                      color: AppTheme.protein,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _MacroField(
                                      controller: _carbsController,
                                      label: l10n.carbs,
                                      color: AppTheme.carbs,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _MacroField(
                                      controller: _fatController,
                                      label: l10n.fat,
                                      color: AppTheme.fat,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Save as custom food checkbox
                      FadeInSlide(
                        index: 3,
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: CheckboxListTile(
                            value: _saveAsCustomFood,
                            onChanged: (v) => setState(() => _saveAsCustomFood = v ?? false),
                            title: Text(
                              l10n.saveAsCustomFood,
                              style: theme.textTheme.bodyMedium,
                            ),
                            subtitle: Text(
                              l10n.saveAsCustomFoodHint,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            secondary: Icon(
                              Icons.bookmark_add_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.trailing,
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
                            onPressed: _save,
                            icon: const Icon(Icons.check, size: 20),
                            label: Text(l10n.save),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
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
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: '0',
            suffixText: 'g',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
