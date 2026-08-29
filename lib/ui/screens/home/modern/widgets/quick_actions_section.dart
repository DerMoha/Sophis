import 'package:flutter/material.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/app_settings.dart';
import 'package:sophis/ui/components/organic_components.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/screens/home/shared/home_actions.dart';

/// Displays quick action buttons either as a compact grid or a card grid.
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
            : _buildChipRow(theme),
      ],
    );
  }

  Widget _buildChipRow(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = actions.length == 1 ? 1 : 2;
        final itemWidth = columnCount == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - 8) / columnCount;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: actions
              .map(
                (action) => SizedBox(
                  width: itemWidth,
                  child: _buildChip(theme, action),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildChip(ThemeData theme, HomeAction action) {
    final color = action.color ?? theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(action.icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
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

      rows.add(
        Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second is SizedBox ? second : second),
          ],
        ),
      );

      if (i + 2 < actions.length) {
        rows.add(const SizedBox(height: AppTheme.spaceSM2));
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
