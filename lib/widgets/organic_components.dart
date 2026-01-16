import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// LIQUID VITALITY COMPONENT LIBRARY
/// Organic, fluid UI components that celebrate nourishment
/// ═══════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
// CACHED COLORS - Pre-computed opacity values to avoid allocations in build
// These static colors prevent creating new Color objects on every frame
// ─────────────────────────────────────────────────────────────────────────────

class _CachedColors {
  // Border colors for dark/light mode
  static final Color borderDark = Colors.white.withValues(alpha: 0.08);
  static final Color borderLight = Colors.black.withValues(alpha: 0.04);
  static final Color borderDarkAlt = Colors.white.withValues(alpha: 0.06);

  // Shadow colors
  static final Color shadowDark = Colors.black.withValues(alpha: 0.3);
  static final Color shadowLight = Colors.black.withValues(alpha: 0.06);
  static final Color shadowDarkStrong = Colors.black.withValues(alpha: 0.4);
  static final Color shadowLightStrong = Colors.black.withValues(alpha: 0.08);

  // Water button colors (static since AppTheme.water is constant)
  static final Color waterBg = AppTheme.water.withValues(alpha: 0.1);
  static final Color waterBorder = AppTheme.water.withValues(alpha: 0.2);
}

// ─────────────────────────────────────────────────────────────────────────────
// GLASS CARD - Frosted glass effect container
// ─────────────────────────────────────────────────────────────────────────────

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

    // Use cached colors to avoid allocations
    final decoration = BoxDecoration(
      color: tint?.withValues(alpha: isDark ? 0.15 : 0.9) ??
          theme.colorScheme.surface.withValues(alpha: isDark ? 0.8 : 0.95),
      borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusLG),
      border: showBorder
          ? Border.all(
              color: isDark ? _CachedColors.borderDark : _CachedColors.borderLight,
              width: 1,
            )
          : null,
      boxShadow: [
        BoxShadow(
          color: isDark ? _CachedColors.shadowDark : _CachedColors.shadowLight,
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
          borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusLG),
          child: content,
        ),
      );
    }

    return content;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORGANIC CARD - Blob-shaped container with soft shadows
// ─────────────────────────────────────────────────────────────────────────────

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
          color: isDark ? _CachedColors.shadowDarkStrong : _CachedColors.shadowLightStrong,
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

// ─────────────────────────────────────────────────────────────────────────────
// RADIAL PROGRESS - Circular progress indicator with gradient
// ─────────────────────────────────────────────────────────────────────────────

class RadialProgress extends StatelessWidget {
  final double value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? backgroundColor;
  final Widget? child;
  final bool showGlow;
  final Gradient? gradient;

  const RadialProgress({
    super.key,
    required this.value,
    this.size = 120,
    this.strokeWidth = 12,
    this.color,
    this.backgroundColor,
    this.child,
    this.showGlow = true,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressColor = color ?? theme.colorScheme.primary;
    final bgColor =
        backgroundColor ?? progressColor.withOpacity(0.1);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow effect
          if (showGlow && value > 0)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, animatedValue, _) {
                return CustomPaint(
                  size: Size(size, size),
                  painter: _RadialGlowPainter(
                    value: animatedValue,
                    color: progressColor.withOpacity(0.3),
                    strokeWidth: strokeWidth + 8,
                  ),
                );
              },
            ),
          // Background ring
          CustomPaint(
            size: Size(size, size),
            painter: _RadialProgressPainter(
              value: 1.0,
              color: bgColor,
              strokeWidth: strokeWidth,
            ),
          ),
          // Progress ring
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, _) {
              return CustomPaint(
                size: Size(size, size),
                painter: _RadialProgressPainter(
                  value: animatedValue,
                  color: progressColor,
                  strokeWidth: strokeWidth,
                  gradient: gradient,
                ),
              );
            },
          ),
          // Center content
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _RadialProgressPainter extends CustomPainter {
  final double value;
  final Color color;
  final double strokeWidth;
  final Gradient? gradient;

  _RadialProgressPainter({
    required this.value,
    required this.color,
    required this.strokeWidth,
    this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (gradient != null) {
      paint.shader = gradient!.createShader(rect);
    } else {
      paint.color = color;
    }

    final sweepAngle = 2 * math.pi * value;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(_RadialProgressPainter oldDelegate) =>
      value != oldDelegate.value ||
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth;
}

class _RadialGlowPainter extends CustomPainter {
  final double value;
  final Color color;
  final double strokeWidth;

  _RadialGlowPainter({
    required this.value,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final sweepAngle = 2 * math.pi * value;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(_RadialGlowPainter oldDelegate) =>
      value != oldDelegate.value;
}

// ─────────────────────────────────────────────────────────────────────────────
// MACRO RING - Small ring progress for macros
// ─────────────────────────────────────────────────────────────────────────────

class MacroRing extends StatelessWidget {
  final String label;
  final double value;
  final double goal;
  final Color color;
  final String unit;
  final double size;

  const MacroRing({
    super.key,
    required this.label,
    required this.value,
    required this.goal,
    required this.color,

    this.unit = 'g',
    this.size = 80,
    this.positiveExcess = false,
    this.excessColor,
  });

  final bool positiveExcess;
  final Color? excessColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Unclamped progress for calculation
    final rawProgress = goal > 0 ? (value / goal) : 0.0;
    final isOver = rawProgress > 1.0;
    
    final finalExcessColor = excessColor ?? AppTheme.error;
    // If over, use the excess color (Green/Red) and show full ring
    final displayColor = isOver && (positiveExcess || !positiveExcess) ? finalExcessColor : color; // Logic simplifies to: if over, use excess color.
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size + 14,
          height: size + 14,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Main Progress
              RadialProgress(
                value: rawProgress.clamp(0.0, 1.0),
                size: size,
                strokeWidth: 6,
                color: color,
                showGlow: false,
              ),
              // Excess Progress (Outer Ring)
              if (isOver)
                RadialProgress(
                  value: (rawProgress - 1.0).clamp(0.0, 1.0),
                  size: size + 12, // Slightly larger
                  strokeWidth: 4,  // Thinner
                  color: finalExcessColor,
                  backgroundColor: Colors.transparent,
                  showGlow: false,
                ),
              // Content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value.toStringAsFixed(0),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: displayColor,
                      ),
                    ),
                    Text(
                      unit,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT BADGE - Compact stat display with icon
// ─────────────────────────────────────────────────────────────────────────────

class StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final String? label;
  final Color? color;
  final bool compact;

  const StatBadge({
    super.key,
    required this.icon,
    required this.value,
    this.label,
    this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor = color ?? theme.colorScheme.primary;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: compact ? 14 : 18,
            color: badgeColor,
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: (compact
                    ? theme.textTheme.labelSmall
                    : theme.textTheme.labelMedium)
                ?.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(
              label!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: badgeColor.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRADIENT ICON BUTTON - Accent colored icon button
// ─────────────────────────────────────────────────────────────────────────────

class GradientIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final String? tooltip;

  const GradientIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.size = 48,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = color ?? theme.colorScheme.primary;

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [buttonColor, buttonColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size / 2),
            boxShadow: [
              BoxShadow(
                color: buttonColor.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER - Styled section title
// ─────────────────────────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsets? padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: theme.textTheme.headlineSmall,
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing!,
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEAL CARD - Expandable meal section
// ─────────────────────────────────────────────────────────────────────────────

class MealCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final double calories;
  final List<Widget> entries;
  final VoidCallback? onAddPressed;
  final VoidCallback? onHeaderTap;
  final Widget? addMenu;
  final Color? color;

  const MealCard({
    super.key,
    required this.title,
    required this.icon,
    required this.calories,
    required this.entries,
    this.onAddPressed,
    this.onHeaderTap,
    this.addMenu,
    this.color,
    this.showMacros = false,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  final bool showMacros;
  final double protein;
  final double carbs;
  final double fat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mealColor = color ?? theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: isDark ? _CachedColors.borderDarkAlt : _CachedColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          // Header - tappable to view meal details
          InkWell(
            onTap: onHeaderTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: mealColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: mealColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleMedium,
                            ),
                            if (onHeaderTap != null) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                              ),
                            ],
                          ],
                        ),
                        if (calories > 0)
                          Text(
                            '${calories.toStringAsFixed(0)} kcal',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: mealColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (calories > 0 && showMacros) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              _buildMiniMacro('P', protein, AppTheme.protein, theme),
                              const SizedBox(width: 8),
                              _buildMiniMacro('C', carbs, AppTheme.carbs, theme),
                              const SizedBox(width: 8),
                              _buildMiniMacro('F', fat, AppTheme.fat, theme),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  addMenu ?? IconButton(
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: mealColor,
                    ),
                    onPressed: onAddPressed,
                  ),
                ],
              ),
            ),
          ),
          // Entries
          if (entries.isNotEmpty) ...[
            Divider(
              height: 1,
              color: isDark ? _CachedColors.borderDarkAlt : _CachedColors.borderLight,
            ),
            ...entries,
          ],
        ],
      ),
    );
  }

  Widget _buildMiniMacro(String label, double value, Color color, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 2,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ${value.toStringAsFixed(0)}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOOD ENTRY TILE - Single food item display
// ─────────────────────────────────────────────────────────────────────────────

class FoodEntryTile extends StatelessWidget {
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const FoodEntryTile({
    super.key,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _MacroChip(
                        label: 'P',
                        value: protein,
                        color: AppTheme.protein,
                      ),
                      const SizedBox(width: 8),
                      _MacroChip(
                        label: 'C',
                        value: carbs,
                        color: AppTheme.carbs,
                      ),
                      const SizedBox(width: 8),
                      _MacroChip(
                        label: 'F',
                        value: fat,
                        color: AppTheme.fat,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '${calories.toStringAsFixed(0)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              ' kcal',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${value.toStringAsFixed(0)}g',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WATER DROP BUTTON - Animated water add button
// ─────────────────────────────────────────────────────────────────────────────

class WaterDropButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool compact;

  const WaterDropButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: _CachedColors.waterBg,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            border: Border.all(
              color: _CachedColors.waterBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.water_drop,
                size: compact ? 14 : 18,
                color: AppTheme.water,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: (compact
                        ? theme.textTheme.labelSmall
                        : theme.textTheme.labelMedium)
                    ?.copyWith(
                  color: AppTheme.water,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ACTION CARD - Dashboard action button
// ─────────────────────────────────────────────────────────────────────────────

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionColor = color ?? theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(
              color: isDark ? _CachedColors.borderDarkAlt : _CachedColors.borderLight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: actionColor,
                  size: 22,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE - Placeholder for empty lists
// ─────────────────────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: theme.colorScheme.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED NUMBER - Large animated number display
// ─────────────────────────────────────────────────────────────────────────────

class AnimatedNumber extends StatelessWidget {
  final double value;
  final String? suffix;
  final TextStyle? style;
  final TextStyle? suffixStyle;

  const AnimatedNumber({
    super.key,
    required this.value,
    this.suffix,
    this.style,
    this.suffixStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return RichText(
          text: TextSpan(
            text: animatedValue.toStringAsFixed(0),
            style: style ?? theme.textTheme.displaySmall,
            children: suffix != null
                ? [
                    TextSpan(
                      text: ' $suffix',
                      style: suffixStyle ??
                          theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}
