import 'package:flutter/material.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/nutrition_totals.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/components/organic/progress.dart';
import 'package:sophis/ui/components/organic/primitives.dart';

class NutritionSummaryCard extends StatelessWidget {
  final String title;
  final String proteinLabel;
  final String carbsLabel;
  final String fatLabel;
  final String? overGoalLabel;
  final NutritionTotals totals;
  final NutritionGoals? goals;

  const NutritionSummaryCard({
    super.key,
    required this.title,
    required this.proteinLabel,
    required this.carbsLabel,
    required this.fatLabel,
    this.overGoalLabel,
    required this.totals,
    required this.goals,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final calorieGoal = goals?.calories ?? 2000;
    final calorieProgress = (totals.calories / calorieGoal).clamp(0.0, 1.5);
    final isOverGoal = totals.calories > calorieGoal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.1),
            theme.colorScheme.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: RadialProgress(
                  value: calorieProgress,
                  size: 80,
                  strokeWidth: 8,
                  color:
                      isOverGoal ? AppTheme.error : theme.colorScheme.primary,
                  showGlow: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        totals.calories.toStringAsFixed(0),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isOverGoal ? AppTheme.error : null,
                        ),
                      ),
                      Text(
                        'kcal',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSM2),
                    Row(
                      children: [
                        _SummaryMacroStat(
                          label: proteinLabel,
                          value: totals.protein,
                          color: AppTheme.protein,
                        ),
                        const SizedBox(width: 16),
                        _SummaryMacroStat(
                          label: carbsLabel,
                          value: totals.carbs,
                          color: AppTheme.carbs,
                        ),
                        const SizedBox(width: 16),
                        _SummaryMacroStat(
                          label: fatLabel,
                          value: totals.fat,
                          color: AppTheme.fat,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isOverGoal && overGoalLabel != null) ...[
            const SizedBox(height: AppTheme.spaceSM2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: AppTheme.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${(totals.calories - calorieGoal).toStringAsFixed(0)} $overGoalLabel',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MealCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final double calories;
  final List<Widget> entries;
  final String? emptyLabel;
  final VoidCallback? onAddPressed;
  final VoidCallback? onHeaderTap;
  final bool showHeaderChevron;
  final Widget? addMenu;
  final Color? color;
  final bool showMacros;
  final double protein;
  final double carbs;
  final double fat;

  const MealCard({
    super.key,
    required this.title,
    required this.icon,
    required this.calories,
    required this.entries,
    this.emptyLabel,
    this.onAddPressed,
    this.onHeaderTap,
    this.showHeaderChevron = true,
    this.addMenu,
    this.color,
    this.showMacros = false,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mealColor = color ?? theme.colorScheme.primary;
    final action = addMenu ??
        (onAddPressed != null
            ? IconButton(
                icon: Icon(Icons.add_circle_outline, color: mealColor),
                onPressed: onAddPressed,
              )
            : null);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: isDark ? CachedColors.borderDarkAlt : CachedColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onHeaderTap,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppTheme.radiusLG),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: mealColor.withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSM),
                          ),
                          child: Icon(icon, color: mealColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    title,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  if (onHeaderTap != null &&
                                      showHeaderChevron) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                      color: theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.5),
                                    ),
                                  ],
                                ],
                              ),
                              if (calories > 0)
                                Text(
                                  '${calories.toStringAsFixed(0)} kcal',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: mealColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              if (calories <= 0 && emptyLabel != null)
                                Text(
                                  emptyLabel!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              if (calories > 0 && showMacros) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    _buildMiniMacro(
                                      'P',
                                      protein,
                                      AppTheme.protein,
                                      theme,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildMiniMacro(
                                      'C',
                                      carbs,
                                      AppTheme.carbs,
                                      theme,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildMiniMacro(
                                      'F',
                                      fat,
                                      AppTheme.fat,
                                      theme,
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: 8),
                  action,
                ],
              ],
            ),
          ),
          if (entries.isNotEmpty) ...[
            Divider(
              height: 1,
              color: isDark
                  ? CachedColors.borderDarkAlt
                  : CachedColors.borderLight,
            ),
            ...entries,
          ],
        ],
      ),
    );
  }

  Widget _buildMiniMacro(
    String label,
    double value,
    Color color,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Container(
          width: 2,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ${value.toStringAsFixed(0)}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _SummaryMacroStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _SummaryMacroStat({
    required this.label,
    required this.value,
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
              '${value.toStringAsFixed(0)}g',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class FoodEntryTile extends StatelessWidget {
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const FoodEntryTile({
    super.key,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _MacroChip(
                        label: 'P',
                        value: protein,
                        color: AppTheme.protein,
                      ),
                      const SizedBox(width: 8),
                      _MacroChip(
                        label: 'C',
                        value: carbs,
                        color: AppTheme.carbs,
                      ),
                      const SizedBox(width: 8),
                      _MacroChip(label: 'F', value: fat, color: AppTheme.fat),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              calories.toStringAsFixed(0),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(' kcal', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '${value.toStringAsFixed(0)}g',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
