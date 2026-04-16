import 'package:flutter/material.dart';
import 'dart:math' as math;

class GradientMeshPainter extends CustomPainter {
  final List<Color> colors;
  final double animationValue;

  GradientMeshPainter({required this.colors, this.animationValue = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    for (int i = 0; i < colors.length; i++) {
      final angle = (i / colors.length) * math.pi * 2 + animationValue;
      final centerX = size.width * (0.5 + 0.3 * math.cos(angle));
      final centerY = size.height * (0.5 + 0.3 * math.sin(angle));

      final gradient = RadialGradient(
        center: Alignment(
          (centerX / size.width) * 2 - 1,
          (centerY / size.height) * 2 - 1,
        ),
        radius: 1.2,
        colors: [
          colors[i].withValues(alpha: 0.4),
          colors[i].withValues(alpha: 0.0),
        ],
      );

      final paint = Paint()..shader = gradient.createShader(rect);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(GradientMeshPainter oldDelegate) =>
      colors != oldDelegate.colors ||
      animationValue != oldDelegate.animationValue;
}
