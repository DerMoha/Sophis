import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'primitives.dart';

class MealCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final double calories;
  final List<Widget> entries;
  final VoidCallback? onAddPressed;
  final VoidCallback? onHeaderTap;
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
    this.onAddPressed,
    this.onHeaderTap,
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
                            borderRadius: BorderRadius.circular(12),
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
                                  if (onHeaderTap != null) ...[
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
                const SizedBox(width: 8),
                addMenu ??
                    IconButton(
                      icon: Icon(Icons.add_circle_outline, color: mealColor),
                      onPressed: onAddPressed,
                    ),
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
