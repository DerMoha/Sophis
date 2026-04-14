import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:sophis/ui/theme/app_theme.dart';

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
    final bgColor = backgroundColor ?? progressColor.withValues(alpha: 0.1);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
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
                    color: progressColor.withValues(alpha: 0.3),
                    strokeWidth: strokeWidth + 8,
                  ),
                );
              },
            ),
          CustomPaint(
            size: Size(size, size),
            painter: _RadialProgressPainter(
              value: 1.0,
              color: bgColor,
              strokeWidth: strokeWidth,
            ),
          ),
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

class MacroRing extends StatelessWidget {
  final String label;
  final double value;
  final double goal;
  final Color color;
  final String unit;
  final double size;
  final bool positiveExcess;
  final Color? excessColor;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rawProgress = goal > 0 ? (value / goal) : 0.0;
    final isOver = rawProgress > 1.0;

    final finalExcessColor = excessColor ?? AppTheme.error;
    final displayColor = isOver ? finalExcessColor : color;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size + 14,
          height: size + 14,
          child: Stack(
            alignment: Alignment.center,
            children: [
              RadialProgress(
                value: rawProgress.clamp(0.0, 1.0),
                size: size,
                strokeWidth: 6,
                color: color,
                showGlow: false,
              ),
              if (isOver)
                RadialProgress(
                  value: (rawProgress - 1.0).clamp(0.0, 1.0),
                  size: size + 12,
                  strokeWidth: 4,
                  color: finalExcessColor,
                  backgroundColor: Colors.transparent,
                  showGlow: false,
                ),
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
