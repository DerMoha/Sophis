import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sophis/ui/components/draft_guard.dart';
import 'package:sophis/utils/number_utils.dart';
import 'package:provider/provider.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/theme/animations.dart';
import 'package:uuid/uuid.dart';
import 'package:sophis/ui/components/organic/utility.dart';

class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recipes),
        actions: [
          IconButton(
            tooltip: l10n.createRecipe,
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              AppTheme.slideRoute(const RecipeCreateScreen()),
            ),
          ),
        ],
      ),
      body: Consumer<NutritionProvider>(
        builder: (context, nutrition, _) {
          final recipes = nutrition.recipes;

          if (recipes.isEmpty) {
            return FadeInSlide(
              index: 0,
              child: Center(
                child: SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.restaurant_outlined,
                    title: l10n.noRecipes,
                    subtitle: l10n.noRecipesSubtitle,
                    action: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        AppTheme.slideRoute(const RecipeCreateScreen()),
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.createRecipe),
                    ),
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              final nutrients = recipe.nutrientsPerServing;

              return FadeInSlide(
                index: index,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(recipe.name),
                    subtitle: Text(
                      '${nutrients.calories.toStringAsFixed(0)} kcal/${l10n.serving} • '
                      '${recipe.servings} ${recipe.servings > 1 ? l10n.servings : l10n.serving}',
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'add',
                          child: Text(l10n.addToMeal),
                        ),
                        PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(l10n.delete),
                        ),
                      ],
                      onSelected: (value) {
                        switch (value) {
                          case 'add':
                            _showAddToMealDialog(context, recipe);
                            break;
                          case 'edit':
                            Navigator.push(
                              context,
                              AppTheme.slideRoute(
                                RecipeCreateScreen(recipe: recipe),
                              ),
                            );
                            break;
                          case 'delete':
                            nutrition.removeRecipe(recipe.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.deleteConfirmation(recipe.name),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                            break;
                        }
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddToMealDialog(BuildContext context, Recipe recipe) {
    final l10n = AppLocalizations.of(context)!;
    final mealTypes = context.read<SettingsProvider>().mealTypes;
    final servingsController = TextEditingController(text: '1');
    String selectedMeal = mealTypes.first.id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.addRecipeName(recipe.name)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: servingsController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.servings,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedMeal,
                decoration: InputDecoration(labelText: l10n.meal),
                items: mealTypes
                    .map(
                      (mealType) => DropdownMenuItem(
                        value: mealType.id,
                        child: Text(mealType.displayName(l10n)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => selectedMeal = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final servings = int.tryParse(servingsController.text) ?? 1;
                context.read<NutritionProvider>().addRecipeAsMeal(
                      recipe,
                      servings,
                      selectedMeal,
                    );
                Navigator.pop(ctx);
              },
              child: Text(l10n.add),
            ),
          ],
        ),
      ),
    );
  }
}

class RecipeCreateScreen extends StatefulWidget {
  final Recipe? recipe;

  const RecipeCreateScreen({super.key, this.recipe});

  @override
  State<RecipeCreateScreen> createState() => _RecipeCreateScreenState();
}

class _RecipeCreateScreenState extends State<RecipeCreateScreen> {
  final _draftKey = GlobalKey<DraftGuardState>();
  bool _isSaving = false;
  String? _servingsError;

  final _nameController = TextEditingController();
  final _servingsController = TextEditingController(text: '1');
  final _notesController = TextEditingController();
  final _ingredients = <RecipeIngredient>[];

  @override
  void initState() {
    super.initState();
    if (widget.recipe != null) {
      _nameController.text = widget.recipe!.name;
      _servingsController.text = widget.recipe!.servings.toString();
      _notesController.text = widget.recipe!.notes ?? '';
      _ingredients.addAll(widget.recipe!.ingredients);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servingsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addIngredient() {
    final nameController = TextEditingController();
    final amountController = TextEditingController(text: '100');
    final caloriesController = TextEditingController();
    final proteinController = TextEditingController();
    final carbsController = TextEditingController();
    final fatController = TextEditingController();

    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addIngredient),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: l10n.name),
              ),
              const SizedBox(height: AppTheme.spaceSM2),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.amountGrams),
              ),
              const SizedBox(height: AppTheme.spaceSM2),
              TextField(
                controller: caloriesController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.calories),
              ),
              const SizedBox(height: AppTheme.spaceSM2),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: proteinController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: l10n.proteinG),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: carbsController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: l10n.carbsG),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fatController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: l10n.fatG),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.required),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              final ingredient = RecipeIngredient(
                id: const Uuid().v4(),
                name: nameController.text,
                amountGrams:
                    NumberUtils.parseInput(amountController.text) ?? 100,
                calories: NumberUtils.parseInput(caloriesController.text) ?? 0,
                protein: NumberUtils.parseInput(proteinController.text) ?? 0,
                carbs: NumberUtils.parseInput(carbsController.text) ?? 0,
                fat: NumberUtils.parseInput(fatController.text) ?? 0,
              );

              setState(() => _ingredients.add(ingredient));
              Navigator.pop(ctx);
            },
            child: Text(l10n.add),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context)!;
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.required),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final servings = int.tryParse(_servingsController.text);
    if (servings == null || servings <= 0) {
      setState(() => _servingsError = l10n.enterValidPositiveNumber);
      return;
    }
    setState(() {
      _servingsError = null;
      _isSaving = true;
    });
    FocusScope.of(context).unfocus();

    final recipe = Recipe(
      id: widget.recipe?.id ?? const Uuid().v4(),
      name: _nameController.text,
      ingredients: _ingredients,
      servings: servings,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      createdAt: widget.recipe?.createdAt ?? DateTime.now(),
    );

    try {
      final provider = context.read<NutritionProvider>();
      if (widget.recipe != null) {
        await provider.updateRecipe(recipe);
      } else {
        await provider.addRecipe(recipe);
      }
      if (!mounted) return;
      _draftKey.currentState?.markSaved();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.entrySaved)));
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.saveEntryFailed)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final totalCal = _ingredients.fold(0.0, (sum, i) => sum + i.calories);
    final servings = int.tryParse(_servingsController.text) ?? 1;
    final perServing = servings > 0 ? totalCal / servings : totalCal;

    return DraftGuard(
      key: _draftKey,
      controllers: [_nameController, _servingsController, _notesController],
      hasOtherChanges: !listEquals(_ingredients,
          widget.recipe?.ingredients ?? const <RecipeIngredient>[],),
      isSaving: _isSaving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.recipe != null ? l10n.editRecipe : l10n.newRecipe),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: Text(l10n.save),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.recipeName),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _servingsController,
                    enabled: !_isSaving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: l10n.servings, errorText: _servingsError,),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  l10n.kcalPerServing(perServing.toStringAsFixed(0)),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Ingredients
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.ingredients, style: theme.textTheme.titleMedium),
                TextButton.icon(
                  onPressed: _addIngredient,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.add),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_ingredients.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    l10n.noIngredientsYet,
                    style: TextStyle(color: theme.disabledColor),
                  ),
                ),
              )
            else
              ..._ingredients.asMap().entries.map((entry) {
                final i = entry.value;
                return Card(
                  key: ValueKey(i.id),
                  child: ListTile(
                    dense: true,
                    title: Text(i.name),
                    subtitle: Text(
                      '${i.amountGrams.toStringAsFixed(0)}g • ${i.calories.toStringAsFixed(0)} kcal',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppTheme.error,),
                      onPressed: () => setState(() => _ingredients.remove(i)),
                    ),
                  ),
                );
              }),

            const SizedBox(height: 24),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.noteOptional,
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
