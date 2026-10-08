import 'package:flutter/material.dart';

import 'package:sophis/ui/components/organic_components.dart';
import 'package:sophis/ui/theme/app_theme.dart';

class SocialIdentity extends StatelessWidget {
  final String name;
  final String subtitle;
  final IconData? icon;
  final Widget? trailing;
  const SocialIdentity({
    super.key,
    required this.name,
    required this.subtitle,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
          alignment: Alignment.center,
          child: icon != null
              ? Icon(icon, color: theme.colorScheme.primary)
              : Text(
                  name.trim().isEmpty
                      ? '♡'
                      : name.trim().characters.first.toUpperCase(),
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class SocialNotice extends StatelessWidget {
  final String message;
  final IconData icon;
  const SocialNotice({
    super.key,
    required this.message,
    this.icon = Icons.lock_outline,
  });
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      );
}

class PartnerTodayCard extends StatelessWidget {
  final Map<String, dynamic>? goals;
  final Map<String, dynamic>? summary;
  final bool progressShared;
  final String? dateLabel;
  const PartnerTodayCard({
    super.key,
    this.goals,
    this.summary,
    required this.progressShared,
    this.dateLabel,
  });

  double? _value(String key) =>
      progressShared ? (summary?[key] as num?)?.toDouble() ?? 0 : null;
  double? _goal(String key) => (goals?[key] as num?)?.toDouble();
  String _description(String key, String label, String unit) =>
      '$label: ${_value(key)?.round() ?? '—'} / ${_goal(key)?.round() ?? '—'} $unit';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final consumed = _value('calories');
    final goal = _goal('calories');
    final progress = consumed != null && goal != null && goal > 0
        ? (consumed / goal).clamp(0.0, 1.0)
        : 0.0;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _description('calories', 'Calories', 'kcal'),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            color: AppTheme.fire,
            backgroundColor: AppTheme.fire.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            minHeight: 8,
          ),
          const SizedBox(height: 20),
          for (final metric in [
            ('protein', 'Protein', AppTheme.protein),
            ('carbs', 'Carbohydrates', AppTheme.carbs),
            ('fat', 'Fat', AppTheme.fat),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MacroProgress(
                description: _description(metric.$1, metric.$2, 'g'),
                value: _value(metric.$1),
                goal: _goal(metric.$1),
                color: metric.$3,
              ),
            ),
        ],
      ),
    );
  }
}

class _MacroProgress extends StatelessWidget {
  final String description;
  final double? value;
  final double? goal;
  final Color color;
  const _MacroProgress({
    required this.description,
    required this.value,
    required this.goal,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: value != null && goal != null && goal! > 0
                ? (value! / goal!).clamp(0.0, 1.0)
                : 0,
            color: color,
            backgroundColor: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            minHeight: 4,
          ),
        ],
      );
}
