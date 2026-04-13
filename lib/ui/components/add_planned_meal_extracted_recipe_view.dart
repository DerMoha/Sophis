import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/meal_plan.dart';
import '../../services/gemini_food_service.dart';
import 'organic/primitives.dart';
import '../theme/app_theme.dart';

class AddPlannedMealExtractedRecipeView extends StatelessWidget {
  final RecipeExtraction recipe;
  final bool isDark;
  final VoidCallback onScanAgain;
  final VoidCallback onAddToMeal;

  const AddPlannedMealExtractedRecipeView({
    super.key,
    required this.recipe,
    required this.isDark,
    required this.onScanAgain,
    required this.onAddToMeal,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.15),
                theme.colorScheme.primary.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      recipe.recipeName ?? l10n.extractedRecipe,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: onScanAgain,
                    tooltip: l10n.scanAgain,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${recipe.servings} ${l10n.servings} • ${recipe.caloriesPerServing.toStringAsFixed(0)} kcal/${l10n.serving}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _MacroChip(
                    label: l10n.protein,
                    value: recipe.proteinPerServing,
                    color: AppTheme.protein,
                  ),
                  const SizedBox(width: 8),
                  _MacroChip(
                    label: l10n.carbs,
                    value: recipe.carbsPerServing,
                    color: AppTheme.carbs,
                  ),
                  const SizedBox(width: 8),
                  _MacroChip(
                    label: l10n.fat,
                    value: recipe.fatPerServing,
                    color: AppTheme.fat,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${l10n.ingredients} (${recipe.ingredients.length})',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(
              color: isDark
                  ? CachedColors.surfaceTintDark06
                  : CachedColors.surfaceTintLight04,
            ),
          ),
          child: Column(
            children: recipe.ingredients.map((ingredient) {
              final emoji = ShoppingCategory.getIcon(ingredient.category);
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ingredient.name,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        ingredient.displayAmount,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onAddToMeal,
            icon: const Icon(Icons.add),
            label: Text(l10n.addToMealPlan),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            '$label ${value.toStringAsFixed(0)}g',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
