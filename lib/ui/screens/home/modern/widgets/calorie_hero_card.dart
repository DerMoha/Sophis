import 'package:flutter/material.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/components/organic_components.dart';
import 'package:sophis/ui/screens/home/modern/widgets/boosted_goal_display.dart';
import 'package:sophis/ui/screens/home/modern/widgets/compact_stat_row.dart';

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

    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    final progressRing = RadialProgress(
      value: progress,
      size: largeText ? 180 : 130,
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
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.calories, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppTheme.spaceSM),
        CompactStatRow(
          icon:
              isOver ? Icons.warning_amber_rounded : Icons.check_circle_outline,
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
    );

    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spaceLG),
      child: largeText
          ? Column(
              children: [
                progressRing,
                const SizedBox(height: AppTheme.spaceLG),
                Align(alignment: Alignment.centerLeft, child: details),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                progressRing,
                const SizedBox(width: AppTheme.spaceLG),
                Expanded(child: details),
              ],
            ),
    );
  }
}
