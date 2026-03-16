import 'package:flutter/material.dart';
import '../../ui/theme/app_theme.dart';

class CachedColors {
  static final Color borderDark = Colors.white.withValues(alpha: 0.08);
  static final Color borderLight = Colors.black.withValues(alpha: 0.04);
  static final Color borderDarkAlt = Colors.white.withValues(alpha: 0.06);
  static final Color shadowDark = Colors.black.withValues(alpha: 0.3);
  static final Color shadowLight = Colors.black.withValues(alpha: 0.06);
  static final Color shadowDarkStrong = Colors.black.withValues(alpha: 0.4);
  static final Color shadowLightStrong = Colors.black.withValues(alpha: 0.08);
  static final Color waterBg = AppTheme.water.withValues(alpha: 0.1);
  static final Color waterBorder = AppTheme.water.withValues(alpha: 0.2);
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? tint;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showBorder;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.tint,
    this.borderRadius,
    this.onTap,
    this.onLongPress,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final decoration = BoxDecoration(
      color: tint?.withValues(alpha: isDark ? 0.15 : 0.9) ??
          theme.colorScheme.surface.withValues(alpha: isDark ? 0.8 : 0.95),
      borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusLG),
      border: showBorder
          ? Border.all(
              color:
                  isDark ? CachedColors.borderDark : CachedColors.borderLight,
              width: 1,
            )
          : null,
      boxShadow: [
        BoxShadow(
          color: isDark ? CachedColors.shadowDark : CachedColors.shadowLight,
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
      ],
    );

    final content = Container(
      margin: margin,
      decoration: decoration,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      ),
    );

    if (onTap != null || onLongPress != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius:
              borderRadius ?? BorderRadius.circular(AppTheme.radiusLG),
          child: content,
        ),
      );
    }

    return content;
  }
}

class OrganicCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final bool useAltRadius;
  final VoidCallback? onTap;

  const OrganicCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.useAltRadius = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final decoration = BoxDecoration(
      color: color ?? theme.colorScheme.surface,
      borderRadius: useAltRadius ? AppTheme.blobRadiusAlt : AppTheme.blobRadius,
      boxShadow: [
        BoxShadow(
          color: isDark
              ? CachedColors.shadowDarkStrong
              : CachedColors.shadowLightStrong,
          blurRadius: 32,
          offset: const Offset(0, 12),
          spreadRadius: -8,
        ),
      ],
    );

    final content = Container(
      margin: margin,
      decoration: decoration,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(24),
        child: child,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius:
              useAltRadius ? AppTheme.blobRadiusAlt : AppTheme.blobRadius,
          child: content,
        ),
      );
    }

    return content;
  }
}
