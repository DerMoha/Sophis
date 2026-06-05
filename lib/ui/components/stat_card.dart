import 'package:flutter/material.dart';

import 'package:sophis/ui/components/organic_components.dart';

/// Header variant for [StatCard]. Two sizes:
/// - [StatHeaderSize.compact]: 32x32 icon box (default). Suits dashboard
///   cards that present one stat (photos, water, quick info).
/// - [StatHeaderSize.large]: 40x40 icon box. Suits cards with stronger
///   primary emphasis (streaks, supplements).
enum StatHeaderSize { compact, large }

/// A semantic card primitive for "one labelled stat with optional body content."
/// Standardises the icon-box + title + optional subtitle + optional trailing
/// header pattern that was previously hand-rolled inside each dashboard card.
///
/// Wraps [GlassCard] and does not introduce a new visual style. When the
/// caller needs a fully custom layout (calorie hero, macros ring row, water
/// progress), they should use [GlassCard] directly rather than fitting into
/// [StatCard].
class StatCard extends StatelessWidget {
  final Widget? icon;
  final String? iconText;
  final Color? iconColor;
  final StatHeaderSize headerSize;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsets padding;
  final Widget? child;
  final bool showBorder;

  const StatCard({
    super.key,
    this.icon,
    this.iconText,
    this.iconColor,
    this.headerSize = StatHeaderSize.compact,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(16),
    this.child,
    this.showBorder = true,
  }) : assert(
          icon != null || iconText != null || title != null,
          'StatCard needs at least one of icon, iconText, or title',
        );

  @override
  Widget build(BuildContext context) {
    final hasHeader = icon != null || iconText != null || title != null;
    return GlassCard(
      onTap: onTap,
      onLongPress: onLongPress,
      showBorder: showBorder,
      padding: hasHeader ? EdgeInsets.zero : padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasHeader) _buildHeader(context),
          if (hasHeader && child != null)
            Padding(padding: padding, child: child),
          if (!hasHeader && child != null) child!,
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final color = iconColor ?? theme.colorScheme.primary;
    final isLarge = headerSize == StatHeaderSize.large;
    final boxSize = isLarge ? 40.0 : 32.0;
    final iconSize = isLarge ? 22.0 : 18.0;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (icon != null || iconText != null)
            Container(
              width: boxSize,
              height: boxSize,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(
                  isLarge ? 12 : 8,
                ),
              ),
              child: Center(
                child: icon ??
                    Text(
                      iconText!,
                      style: TextStyle(fontSize: iconSize),
                    ),
              ),
            ),
          if (icon != null || iconText != null)
            const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) title!,
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  subtitle!,
                ],
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
  }
}
