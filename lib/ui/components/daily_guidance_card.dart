import 'package:flutter/material.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/services/nutrition_guidance_service.dart';
import 'package:sophis/ui/screens/goals_setup_screen.dart';
import 'package:sophis/ui/theme/app_theme.dart';

class DailyGuidanceCard extends StatelessWidget {
  final NutritionGuidance guidance;

  const DailyGuidanceCard({super.key, required this.guidance});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (!guidance.hasGoal) {
      return _card(
        context,
        icon: Icons.lightbulb_outline,
        title: l10n.dailyGuidance,
        body: l10n.dailyGuidanceNoGoal,
        action: FilledButton.tonalIcon(
          onPressed: () => Navigator.push(
            context,
            AppTheme.slideRoute(const GoalsSetupScreen()),
          ),
          icon: const Icon(Icons.flag_outlined, size: 17),
          label: Text(l10n.dailyGuidanceNoGoalAction),
        ),
      );
    }

    final isOver = guidance.isOverGoal;
    final body = isOver
        ? l10n.dailyGuidanceOverGoal(
            guidance.remainingCalories.abs().toStringAsFixed(0),
          )
        : l10n.dailyGuidanceRemaining(
            guidance.remainingCalories.toStringAsFixed(0),
            guidance.remainingProtein.toStringAsFixed(0),
          );
    final children = <Widget>[
      Text(body, style: theme.textTheme.bodyMedium),
      if (!isOver) ...[
        const SizedBox(height: 10),
        Text(
          l10n.dailyGuidanceBudget(
            guidance.suggestedCaloriesPerSlot.toStringAsFixed(0),
            guidance.suggestedProteinPerSlot.toStringAsFixed(0),
          ),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (guidance.fittingPlannedMeals.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            l10n.dailyGuidancePlanned,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: guidance.fittingPlannedMeals
                .map(
                  (meal) => Chip(
                    label: Text(
                      '${meal.name} · ${meal.calories.toStringAsFixed(0)} kcal',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
        ],
        if (guidance.fittingRecentFoods.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            l10n.dailyGuidanceRecent,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            guidance.fittingRecentFoods.map((food) => food.name).join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    ];

    return _card(
      context,
      icon: isOver ? Icons.wb_sunny_outlined : Icons.lightbulb_outline,
      title: l10n.dailyGuidance,
      bodyWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? body,
    Widget? bodyWidget,
    Widget? action,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                bodyWidget ??
                    Text(body ?? '', style: theme.textTheme.bodyMedium),
                if (action != null) ...[
                  const SizedBox(height: 10),
                  action,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
