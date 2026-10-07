import 'package:flutter/material.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/components/organic_components.dart';

/// Daily energy balance, with the next useful number given priority.
class CalorieHeroCard extends StatelessWidget {
  final Widget? macros;
  final double consumed;
  final double baseGoal;
  final double effectiveGoal;
  final double remaining;
  final double progress;
  final double burnedCalories;

  const CalorieHeroCard({
    super.key,
    this.macros,
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
    final color = isOver ? AppTheme.warning : theme.colorScheme.primary;

    return GlassCard(
      tint: theme.colorScheme.primary,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_fire_department_outlined,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.calories, style: theme.textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              AnimatedNumber(
                value: remaining.abs(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'kcal ${isOver ? l10n.over : l10n.remaining}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: l10n.calories,
            value:
                '${consumed.toStringAsFixed(0)} / ${effectiveGoal.toStringAsFixed(0)} kcal',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              child: LinearProgressIndicator(
                value: progress.isFinite ? progress.clamp(0.0, 1.0) : 0,
                minHeight: 6,
                color: color,
                backgroundColor: color.withValues(alpha: 0.12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 20,
            runSpacing: 8,
            children: [
              Text(
                '${consumed.toStringAsFixed(0)} kcal',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '${l10n.goal}: ${effectiveGoal.toStringAsFixed(0)} kcal',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          if (burnedCalories > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department_outlined,
                  size: 16,
                  color: AppTheme.fire,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.burned('${burnedCalories.toStringAsFixed(0)} kcal'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          if (macros != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(),
            ),
            macros!,
          ],
        ],
      ),
    );
  }
}
