import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/food_entry.dart';
import '../models/food_item.dart';
import '../models/shareable_meal.dart';
import '../services/nutrition_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/organic_components.dart';
import 'add_food_screen.dart';
import 'food_search_screen.dart';
import 'barcode_scanner_screen.dart';
import 'ai_food_camera_screen.dart';
import 'share_meal_screen.dart';

/// Full-screen detail view for a single meal (breakfast, lunch, etc.)
class MealDetailScreen extends StatelessWidget {
  final String mealType;
  final String mealTitle;
  final IconData mealIcon;

  const MealDetailScreen({
    super.key,
    required this.mealType,
    required this.mealTitle,
    required this.mealIcon,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(mealIcon, size: 24),
            const SizedBox(width: 8),
            Text(mealTitle),
          ],
        ),
        actions: [
          Consumer<NutritionProvider>(
            builder: (context, nutrition, _) {
              final entries = nutrition.getEntriesByMeal(mealType);
              if (entries.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: l10n.share,
                onPressed: () => _shareMeal(context, entries),
              );
            },
          ),
        ],
      ),
      body: Consumer<NutritionProvider>(
        builder: (context, nutrition, _) {
          final entries = nutrition.getEntriesByMeal(mealType);
          final totalCalories = entries.fold(0.0, (sum, e) => sum + e.calories);
          final totalProtein = entries.fold(0.0, (sum, e) => sum + e.protein);
          final totalCarbs = entries.fold(0.0, (sum, e) => sum + e.carbs);
          final totalFat = entries.fold(0.0, (sum, e) => sum + e.fat);

          if (entries.isEmpty) {
            return _buildEmptyState(context, l10n, theme);
          }

          return Column(
            children: [
              // Summary card
              Padding(
                padding: const EdgeInsets.all(16),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            totalCalories.toStringAsFixed(0),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            ' kcal',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _MacroSummary(
                            label: l10n.protein,
                            value: totalProtein,
                            color: AppTheme.protein,
                          ),
                          _MacroSummary(
                            label: l10n.carbs,
                            value: totalCarbs,
                            color: AppTheme.carbs,
                          ),
                          _MacroSummary(
                            label: l10n.fat,
                            value: totalFat,
                            color: AppTheme.fat,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Entries list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MealEntryCard(
                        entry: entry,
                        mealType: mealType,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOptions(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              mealIcon,
              size: 36,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.noEntries,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tapToAdd,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _shareMeal(BuildContext context, List<FoodEntry> entries) {
    final meal = ShareableMeal.fromFoodEntries(entries, title: mealTitle);
    Navigator.push(
      context,
      AppTheme.slideRoute(ShareMealScreen(meal: meal)),
    );
  }

  void _showAddOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
              title: Text(l10n.manualEntry),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, AppTheme.slideRoute(AddFoodScreen(meal: mealType)));
              },
            ),
            ListTile(
              leading: Icon(Icons.search_outlined, color: theme.colorScheme.primary),
              title: Text(l10n.searchFood),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, AppTheme.slideRoute(FoodSearchScreen(meal: mealType)));
              },
            ),
            ListTile(
              leading: Icon(Icons.qr_code_scanner_outlined, color: theme.colorScheme.primary),
              title: Text(l10n.scanBarcode),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, AppTheme.slideRoute(BarcodeScannerScreen(meal: mealType)));
              },
            ),
            ListTile(
              leading: Icon(Icons.auto_awesome_outlined, color: theme.colorScheme.primary),
              title: Text(l10n.aiRecognition),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, AppTheme.slideRoute(AIFoodCameraScreen(meal: mealType)));
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Card for a single food entry with edit controls
class _MealEntryCard extends StatelessWidget {
  final FoodEntry entry;
  final String mealType;

  const _MealEntryCard({
    required this.entry,
    required this.mealType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        children: [
          // Main content - tappable for quick actions
          InkWell(
            onTap: () => _showQuickActions(context, l10n),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMD)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.calories.toStringAsFixed(0)} kcal',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Macro row
                  Row(
                    children: [
                      _MacroChip(label: 'P', value: entry.protein, color: AppTheme.protein),
                      const SizedBox(width: 12),
                      _MacroChip(label: 'C', value: entry.carbs, color: AppTheme.carbs),
                      const SizedBox(width: 12),
                      _MacroChip(label: 'F', value: entry.fat, color: AppTheme.fat),
                      const Spacer(),
                      Icon(
                        Icons.touch_app_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Quick portion adjustment bar
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusMD)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _PortionButton(
                    label: '-25%',
                    onTap: () => _adjustPortion(context, 0.75),
                  ),
                  _PortionButton(
                    label: '-10%',
                    onTap: () => _adjustPortion(context, 0.9),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      '100%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _PortionButton(
                    label: '+10%',
                    onTap: () => _adjustPortion(context, 1.1),
                  ),
                  _PortionButton(
                    label: '+25%',
                    onTap: () => _adjustPortion(context, 1.25),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _adjustPortion(BuildContext context, double factor) {
    final nutrition = context.read<NutritionProvider>();
    final updatedEntry = entry.scaledBy(factor);
    nutrition.updateFoodEntry(updatedEntry);
  }

  void _showQuickActions(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with entry info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${entry.calories.toStringAsFixed(0)} kcal',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Actions
            ListTile(
              leading: Icon(Icons.swap_horiz_outlined, color: theme.colorScheme.primary),
              title: Text(l10n.moveTo),
              subtitle: Text(l10n.moveToMealSubtitle),
              onTap: () {
                Navigator.pop(ctx);
                _showMoveToMealDialog(context, l10n);
              },
            ),
            ListTile(
              leading: Icon(Icons.copy_outlined, color: theme.colorScheme.primary),
              title: Text(l10n.duplicate),
              subtitle: Text(l10n.duplicateSubtitle),
              onTap: () {
                Navigator.pop(ctx);
                _duplicateEntry(context, l10n);
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
              title: Text(l10n.editEntry),
              subtitle: Text(l10n.editEntrySubtitle),
              onTap: () {
                Navigator.pop(ctx);
                _showEditDialog(context, l10n);
              },
            ),
            ListTile(
              leading: Icon(Icons.bookmark_add_outlined, color: theme.colorScheme.primary),
              title: Text(l10n.saveToMyFoods),
              subtitle: Text(l10n.saveToMyFoodsSubtitle),
              onTap: () {
                Navigator.pop(ctx);
                _saveToMyFoods(context, l10n);
              },
            ),
            ListTile(
              leading: Icon(Icons.share_outlined, color: theme.colorScheme.primary),
              title: Text(l10n.share),
              onTap: () {
                Navigator.pop(ctx);
                _shareEntry(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              title: Text(l10n.delete, style: TextStyle(color: theme.colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirmation(context, l10n);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMoveToMealDialog(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final meals = [
      ('breakfast', l10n.breakfast, Icons.wb_twilight_rounded),
      ('lunch', l10n.lunch, Icons.wb_sunny_rounded),
      ('dinner', l10n.dinner, Icons.nights_stay_rounded),
      ('snack', l10n.snacks, Icons.cookie_outlined),
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.moveTo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: meals.where((m) => m.$1 != mealType).map((meal) {
            return ListTile(
              leading: Icon(meal.$3, color: theme.colorScheme.primary),
              title: Text(meal.$2),
              onTap: () {
                Navigator.pop(ctx);
                final nutrition = context.read<NutritionProvider>();
                final updatedEntry = entry.copyWith(meal: meal.$1);
                nutrition.updateFoodEntry(updatedEntry);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.movedTo(meal.$2))),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _duplicateEntry(BuildContext context, AppLocalizations l10n) {
    final nutrition = context.read<NutritionProvider>();
    nutrition.duplicateFoodEntry(entry);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.entryDuplicated)),
    );
  }

  void _showEditDialog(BuildContext context, AppLocalizations l10n) {
    final nameController = TextEditingController(text: entry.name);
    final caloriesController = TextEditingController(text: entry.calories.toStringAsFixed(0));
    final proteinController = TextEditingController(text: entry.protein.toStringAsFixed(1));
    final carbsController = TextEditingController(text: entry.carbs.toStringAsFixed(1));
    final fatController = TextEditingController(text: entry.fat.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editEntry),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.name,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: caloriesController,
                decoration: InputDecoration(
                  labelText: l10n.calories,
                  suffixText: 'kcal',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: proteinController,
                      decoration: InputDecoration(
                        labelText: l10n.protein,
                        suffixText: 'g',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: carbsController,
                      decoration: InputDecoration(
                        labelText: l10n.carbs,
                        suffixText: 'g',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: fatController,
                      decoration: InputDecoration(
                        labelText: l10n.fat,
                        suffixText: 'g',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          FilledButton(
            onPressed: () {
              final updatedEntry = entry.copyWith(
                name: nameController.text.trim(),
                calories: double.tryParse(caloriesController.text) ?? entry.calories,
                protein: double.tryParse(proteinController.text) ?? entry.protein,
                carbs: double.tryParse(carbsController.text) ?? entry.carbs,
                fat: double.tryParse(fatController.text) ?? entry.fat,
              );
              context.read<NutritionProvider>().updateFoodEntry(updatedEntry);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.entrySaved)),
              );
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _saveToMyFoods(BuildContext context, AppLocalizations l10n) {
    final customFood = FoodItem(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: entry.name,
      category: 'custom',
      caloriesPer100g: entry.calories,
      proteinPer100g: entry.protein,
      carbsPer100g: entry.carbs,
      fatPer100g: entry.fat,
    );
    context.read<NutritionProvider>().addCustomFood(customFood);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.customFoodSaved)),
    );
  }

  void _shareEntry(BuildContext context) {
    final meal = ShareableMeal.fromFoodEntries([entry]);
    Navigator.push(
      context,
      AppTheme.slideRoute(ShareMealScreen(meal: meal)),
    );
  }

  void _showDeleteConfirmation(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteConfirmation(entry.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              context.read<NutritionProvider>().removeFoodEntry(entry.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

/// Quick portion adjustment button
class _PortionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PortionButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncrease = label.startsWith('+');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: (isIncrease ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isIncrease ? AppTheme.success : AppTheme.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Macro chip for entry display
class _MacroChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${value.toStringAsFixed(0)}g',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Summary display for a macro
class _MacroSummary extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroSummary({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(0)}g',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
