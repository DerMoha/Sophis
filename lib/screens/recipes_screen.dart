import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/recipe.dart';
import '../services/nutrition_provider.dart';
import '../theme/app_theme.dart';

class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recipes),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecipeCreateScreen()),
            ),
          ),
        ],
      ),
      body: Consumer<NutritionProvider>(
        builder: (context, nutrition, _) {
          final recipes = nutrition.recipes;

          if (recipes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_outlined, size: 64, color: theme.disabledColor),
                  const SizedBox(height: 16),
                  Text(l10n.noEntries, style: TextStyle(color: theme.disabledColor)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RecipeCreateScreen()),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Recipe'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              final nutrients = recipe.nutrientsPerServing;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(recipe.name),
                  subtitle: Text(
                    '${nutrients['calories']?.toStringAsFixed(0)} kcal/serving • '
                    '${recipe.servings} serving${recipe.servings > 1 ? 's' : ''}',
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'add', child: Text('Add to meal')),
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'add':
                          _showAddToMealDialog(context, recipe);
                          break;
                        case 'edit':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecipeCreateScreen(recipe: recipe),
                            ),
                          );
                          break;
                        case 'delete':
                          nutrition.removeRecipe(recipe.id);
                          break;
                      }
                    },
                  ),
                  onTap: () => _showAddToMealDialog(context, recipe),
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
    final servingsController = TextEditingController(text: '1');
    String selectedMeal = 'lunch';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add ${recipe.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: servingsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Servings',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: selectedMeal,
                decoration: const InputDecoration(labelText: 'Meal'),
                items: [
                  DropdownMenuItem(value: 'breakfast', child: Text(l10n.breakfast)),
                  DropdownMenuItem(value: 'lunch', child: Text(l10n.lunch)),
                  DropdownMenuItem(value: 'dinner', child: Text(l10n.dinner)),
                  DropdownMenuItem(value: 'snack', child: Text(l10n.snacks)),
                ],
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
        title: const Text('Add Ingredient'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (g)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Calories'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: proteinController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Protein (g)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: carbsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Carbs (g)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fatController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Fat (g)'),
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
              if (nameController.text.isEmpty) return;

              final ingredient = RecipeIngredient(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text,
                amountGrams: double.tryParse(amountController.text) ?? 100,
                calories: double.tryParse(caloriesController.text) ?? 0,
                protein: double.tryParse(proteinController.text) ?? 0,
                carbs: double.tryParse(carbsController.text) ?? 0,
                fat: double.tryParse(fatController.text) ?? 0,
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
    if (_nameController.text.isEmpty) return;

    final recipe = Recipe(
      id: widget.recipe?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      ingredients: _ingredients,
      servings: int.tryParse(_servingsController.text) ?? 1,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      createdAt: widget.recipe?.createdAt ?? DateTime.now(),
    );

    final provider = context.read<NutritionProvider>();
    if (widget.recipe != null) {
      await provider.updateRecipe(recipe);
    } else {
      await provider.addRecipe(recipe);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final totalCal = _ingredients.fold(0.0, (sum, i) => sum + i.calories);
    final servings = int.tryParse(_servingsController.text) ?? 1;
    final perServing = servings > 0 ? totalCal / servings : totalCal;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe != null ? 'Edit Recipe' : 'New Recipe'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Recipe Name'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _servingsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Servings'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${perServing.toStringAsFixed(0)} kcal/serving',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Ingredients
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ingredients', style: theme.textTheme.titleMedium),
              TextButton.icon(
                onPressed: _addIngredient,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_ingredients.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No ingredients yet',
                  style: TextStyle(color: theme.disabledColor),
                ),
              ),
            )
          else
            ..._ingredients.asMap().entries.map((entry) {
              final i = entry.value;
              return Card(
                child: ListTile(
                  dense: true,
                  title: Text(i.name),
                  subtitle: Text('${i.amountGrams.toStringAsFixed(0)}g • ${i.calories.toStringAsFixed(0)} kcal'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                    onPressed: () => setState(() => _ingredients.remove(i)),
                  ),
                ),
              );
            }),

          const SizedBox(height: 24),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}
