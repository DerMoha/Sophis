import 'package:flutter/material.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/organic_components.dart';
import 'boosted_goal_display.dart';
import 'compact_stat_row.dart';

/// The main calorie display card for the modern home screen.
class CalorieHeroCard extends StatelessWidget {
  final double consumed;
  final double baseGoal;
  final double effectiveGoal;
  final double remaining;
  final double progress;
  final double burnedCalories;

  const CalorieHeroCard({
    super.key,
    required this.consumed,
    required this.baseGoal,
    required this.effectiveGoal,
    required this.remaining,
    required this.progress,
    required this.burnedCalories,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isOver = remaining < 0;
    final statusColor = isOver ? AppTheme.error : AppTheme.success;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RadialProgress(
            value: progress,
            size: 130,
            strokeWidth: 12,
            color: theme.colorScheme.primary,
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.6),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedNumber(
                  value: consumed,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                BoostedGoalDisplay(
                  baseGoal: baseGoal,
                  effectiveGoal: effectiveGoal,
                  burnedCalories: burnedCalories,
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
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.calories, style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                CompactStatRow(
                  icon: isOver
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  value: remaining.abs().toStringAsFixed(0),
                  label: isOver ? l10n.over : l10n.remaining,
                  color: statusColor,
                ),
                if (burnedCalories > 0) ...[
                  const SizedBox(height: 8),
                  CompactStatRow(
                    icon: Icons.local_fire_department_rounded,
                    value: burnedCalories.toStringAsFixed(0),
                    label: l10n.burned('').trim(),
                    color: AppTheme.fire,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
