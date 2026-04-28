import 'package:flutter/material.dart';
import 'package:sophis/ui/theme/app_theme.dart';

/// Standardized loading indicator with optional label.
class LoadingState extends StatelessWidget {
  final String? label;

  const LoadingState({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
          if (label != null) ...[
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              label!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rounded square icon container used throughout the app.
class IconBox extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final double iconSize;
  final double borderRadius;

  const IconBox({
    super.key,
    required this.icon,
    this.color,
    this.backgroundColor,
    this.size = 44,
    this.iconSize = AppTheme.iconMD,
    this.borderRadius = AppTheme.radiusSM,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? effectiveColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(icon, size: iconSize, color: effectiveColor),
    );
  }
}

/// Compact macro chip displayed as a row: colored dot + value.
class MacroChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final int decimals;

  const MacroChip({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.decimals = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${value.toStringAsFixed(decimals)}g',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

/// Macro summary displayed as a column: colored dot + value + label.
class MacroSummary extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final int decimals;

  const MacroSummary({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.decimals = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(decimals)}g',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Empty day hint used in diary and planner screens.
class EmptyDayHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyDayHint({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 28,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppTheme.spaceXS),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
