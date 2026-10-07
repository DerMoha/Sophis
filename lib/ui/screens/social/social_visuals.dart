import 'package:flutter/material.dart';

import 'package:sophis/ui/components/organic_components.dart';
import 'package:sophis/ui/theme/app_theme.dart';

class SocialIdentity extends StatelessWidget {
  final String name;
  final String subtitle;
  final IconData? icon;
  final Widget? trailing;
  const SocialIdentity(
      {super.key,
      required this.name,
      required this.subtitle,
      this.icon,
      this.trailing,});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),),
          alignment: Alignment.center,
          child: icon != null
              ? Icon(icon, color: theme.colorScheme.primary)
              : Text(
                  name.trim().isEmpty
                      ? '♡'
                      : name.trim().characters.first.toUpperCase(),
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: theme.colorScheme.primary),),),
      const SizedBox(width: 14),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: theme.textTheme.titleLarge),
        const SizedBox(height: 3),
        Text(subtitle,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),),
      ],),),
      if (trailing != null) trailing!,
    ],);
  }
}

class SocialNotice extends StatelessWidget {
  final String message;
  final IconData icon;
  const SocialNotice(
      {super.key, required this.message, this.icon = Icons.lock_outline,});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon,
            size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant,),
        const SizedBox(width: 8),
        Expanded(
            child: Text(message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,),),),
      ],),);
}

class PartnerTodayCard extends StatelessWidget {
  final Map<String, dynamic>? goals;
  final Map<String, dynamic>? summary;
  final bool progressShared;
  final String? dateLabel;
  const PartnerTodayCard(
      {super.key,
      this.goals,
      this.summary,
      required this.progressShared,
      this.dateLabel,});

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
    final energy = Semantics(
        label: _description('calories', 'Calories', 'kcal'),
        child: RadialProgress(
            value: progress,
            size: 132,
            strokeWidth: 10,
            color: AppTheme.fire,
            showGlow: false,
            child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.local_fire_department_outlined,
                      color: AppTheme.fire, size: 20,),
                  Text(consumed?.round().toString() ?? '—',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),),
                  Text('kcal shared', style: theme.textTheme.labelSmall),
                ],),),),);
    final detail =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('A day together', style: theme.textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text(
          goal == null
              ? 'Nutrition target not shared'
              : 'Daily goal · ${goal.round()} kcal',
          style: theme.textTheme.bodyMedium,),
      const SizedBox(height: 6),
      Text(_description('calories', 'Calories', 'kcal'),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),),
    ],);
    return GlassCard(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.wb_sunny_outlined,
                size: 18, color: theme.colorScheme.primary,),
            const SizedBox(width: 8),
            Expanded(child: Text('SHARED TODAY',
                style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.4,
                    color: theme.colorScheme.onSurfaceVariant,),),),
          ],),
          if (dateLabel != null)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(dateLabel!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),),),
          const SizedBox(height: 22),
          LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth < 290 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Center(child: energy),
                          const SizedBox(height: 20),
                          detail,
                        ],)
                  : Row(children: [
                      energy,
                      const SizedBox(width: 22),
                      Expanded(child: detail),
                    ],),),
          const SizedBox(height: 22),
          Divider(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final columns = MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
                    constraints.maxWidth < 260
                ? 1
                : 3;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(spacing: 12, runSpacing: 16, children: [
              for (final metric in [
                ('protein', 'Protein', AppTheme.protein),
                ('carbs', 'Carbohydrates', AppTheme.carbs),
                ('fat', 'Fat', AppTheme.fat),
              ])
                SizedBox(
                    width: width,
                    child: _MacroProgress(
                        label: metric.$2,
                        description: _description(metric.$1, metric.$2, 'g'),
                        value: _value(metric.$1),
                        goal: _goal(metric.$1),
                        color: metric.$3,),),
            ],);
          },),
        ],),);
  }
}

class _MacroProgress extends StatelessWidget {
  final String label;
  final String description;
  final double? value;
  final double? goal;
  final Color color;
  const _MacroProgress(
      {required this.label,
      required this.description,
      required this.value,
      required this.goal,
      required this.color,});
  @override
  Widget build(BuildContext context) => Semantics(
      label: description,
      child: Column(children: [
        RadialProgress(
            value: value != null && goal != null && goal! > 0
                ? (value! / goal!).clamp(0.0, 1.0)
                : 0,
            size: 64,
            strokeWidth: 6,
            color: color,
            showGlow: false,
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(value?.round().toString() ?? '—',
                        style: Theme.of(context).textTheme.titleLarge,),),),),
        const SizedBox(height: 10),
        Text(description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,),),
      ],),);
}
