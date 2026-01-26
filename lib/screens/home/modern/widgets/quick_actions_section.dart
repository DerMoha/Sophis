import 'package:flutter/material.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../models/app_settings.dart';
import '../../../../widgets/organic_components.dart';
import '../../shared/home_actions.dart';

/// Displays quick action buttons either as a horizontal row of chips or a grid.
class QuickActionsSection extends StatelessWidget {
  final List<HomeAction> actions;
  final QuickActionSize size;

  const QuickActionsSection({
    super.key,
    required this.actions,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            l10n.quickActions,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        size == QuickActionSize.large
            ? _buildGrid(context, theme)
            : _buildChipRow(context, theme),
      ],
    );
  }

  Widget _buildChipRow(BuildContext context, ThemeData theme) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => _buildChip(theme, actions[index]),
      ),
    );
  }

  Widget _buildChip(ThemeData theme, HomeAction action) {
    final color = action.color ?? theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                action.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, ThemeData theme) {
    final rows = <Widget>[];

    for (var i = 0; i < actions.length; i += 2) {
      final first = _buildCard(theme, actions[i]);
      final second = i + 1 < actions.length
          ? _buildCard(theme, actions[i + 1])
          : const SizedBox.shrink();

      rows.add(Row(
        children: [
          Expanded(child: first),
          const SizedBox(width: 12),
          Expanded(child: second is SizedBox ? second : second),
        ],
      ));

      if (i + 2 < actions.length) {
        rows.add(const SizedBox(height: 12));
      }
    }

    return Column(children: rows);
  }

  Widget _buildCard(ThemeData theme, HomeAction action) {
    return QuickActionCard(
      icon: action.icon,
      label: action.label,
      color: action.color,
      onTap: action.onTap,
    );
  }
}
