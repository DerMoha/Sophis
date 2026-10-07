import 'package:flutter/material.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/services/nutrition_guidance_service.dart';
import 'package:sophis/ui/theme/app_theme.dart';

class WeeklyReviewCard extends StatelessWidget {
  final WeeklyNutritionReview review;

  const WeeklyReviewCard({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final trend = review.weightTrendKg;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.weeklyReview, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTheme.spaceSM2),
            if (!review.hasEnoughHistory)
              Text(
                l10n.weeklyReviewIncomplete(review.loggedDays),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: AppTheme.spaceSM2),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric(
                  context,
                  label: l10n.avgCalories,
                  value: review.average.calories.toStringAsFixed(0),
                  unit: 'kcal',
                  color: theme.colorScheme.primary,
                ),
                _metric(
                  context,
                  label: l10n.avgProtein,
                  value: review.average.protein.toStringAsFixed(0),
                  unit: 'g',
                  color: AppTheme.protein,
                ),
                _metric(
                  context,
                  label: l10n.avgCarbs,
                  value: review.average.carbs.toStringAsFixed(0),
                  unit: 'g',
                  color: AppTheme.carbs,
                ),
                _metric(
                  context,
                  label: l10n.avgFat,
                  value: review.average.fat.toStringAsFixed(0),
                  unit: 'g',
                  color: AppTheme.fat,
                ),
              ],
            ),
            if (review.goalHitDays > 0) ...[
              const SizedBox(height: AppTheme.spaceSM2),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.daysOnTrack(review.goalHitDays, 7),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppTheme.spaceSM2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.monitor_weight_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    trend == null
                        ? l10n.weeklyReviewNoWeight
                        : '${l10n.weightTrend}: ${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(1)} kg',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(
    BuildContext context, {
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 3),
          Text(
            '$value $unit',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
