import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/partner_day.dart';
import 'package:sophis/providers/partner_provider.dart';
import 'package:sophis/ui/components/organic_components.dart';
import 'package:sophis/ui/screens/partner/partner_day_screen.dart';
import 'package:sophis/ui/theme/app_theme.dart';

/// Home dashboard card: what the partner has left today. Hidden unless paired.
class PartnerCard extends StatelessWidget {
  const PartnerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final partner = context.watch<PartnerProvider?>();
    final link = partner?.link;
    if (partner == null || link == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        onTap: () => Navigator.push(
          context,
          AppTheme.slideRoute(const PartnerDayScreen()),
        ),
        child: PartnerDaySummary(
          name: link.partnerName,
          day: partner.partnerToday,
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class PartnerDaySummary extends StatelessWidget {
  final String name;
  final PartnerDay? day;
  final Widget? trailing;

  const PartnerDaySummary({
    super.key,
    required this.name,
    required this.day,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    );
    final eaten = day?.totals.calories ?? 0;
    final goal = day?.goals?.calories;
    final remaining = day?.remainingCalories;
    final headline = remaining == null
        ? (day == null || day!.entries.isEmpty
            ? l10n.partnerNothingLogged
            : l10n.partnerNoGoal)
        : remaining >= 0
            ? l10n.partnerLeft(number.format(remaining.round()))
            : l10n.partnerOver(number.format(-remaining.round()));
    final progress = goal == null || goal <= 0
        ? 0.0
        : (eaten / (goal + (day?.burned ?? 0))).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              child: Text(
                name.trim().isEmpty
                    ? '♡'
                    : name.trim().characters.first.toUpperCase(),
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.titleMedium),
                  Text(
                    headline,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: remaining != null && remaining < 0
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (goal != null)
              Text(
                l10n.partnerEatenOf(
                  number.format(eaten.round()),
                  number.format(goal.round()),
                ),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            if (trailing != null) trailing!,
          ],
        ),
        if (goal != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusXXS),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ],
    );
  }
}
