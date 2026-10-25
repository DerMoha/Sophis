import 'package:flutter/material.dart';

import 'package:sophis/ui/theme/app_theme.dart';

/// Canonical low-decoration surface for launch UI.
class AppSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.35),
        ),
      ),
      child: child,
    );
  }
}

class AppSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final String? footer;

  const AppSection({
    super.key,
    required this.title,
    required this.children,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        AppSurface(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              footer!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// Shared layout for every row inside an [AppSection].
class AppRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;
  final bool destructive;
  final bool isLoading;
  final bool selected;

  const AppRow({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = true,
    this.destructive = false,
    this.isLoading = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        destructive ? theme.colorScheme.error : theme.colorScheme.primary;
    final row = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: isLoading
                ? Padding(
                    padding: const EdgeInsets.all(9),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  )
                : Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: destructive ? theme.colorScheme.error : null,
                    fontWeight: selected ? FontWeight.w600 : null,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(onTap: isLoading ? null : onTap, child: row),
    );
  }
}

class AppNavigationRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final String? subtitle;
  final bool showDivider;
  final bool external;

  const AppNavigationRow({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.showDivider = true,
    this.external = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppRow(
      title: title,
      icon: icon,
      subtitle: subtitle,
      showDivider: showDivider,
      onTap: onTap,
      trailing: Icon(
        external ? Icons.open_in_new : Icons.chevron_right,
        size: external ? 18 : 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class AppSwitchRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;
  final bool showDivider;

  const AppSwitchRow({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: AppRow(
        title: title,
        icon: icon,
        subtitle: subtitle,
        showDivider: showDivider,
        onTap: () => onChanged(!value),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}

class AppOptionRow extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? subtitle;
  final bool showDivider;

  const AppOptionRow({
    super.key,
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppRow(
      title: title,
      icon: icon,
      subtitle: subtitle,
      showDivider: showDivider,
      selected: selected,
      onTap: onTap,
      trailing: Icon(
        selected ? Icons.check_circle : Icons.circle_outlined,
        size: 22,
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.outline.withValues(alpha: 0.5),
      ),
    );
  }
}
