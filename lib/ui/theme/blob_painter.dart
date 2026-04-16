import 'package:flutter/material.dart';
import 'dart:math' as math;

class BlobPainter extends CustomPainter {
  final Color color;
  final double animationValue;

  BlobPainter({required this.color, this.animationValue = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    final offset = math.sin(animationValue * math.pi * 2) * 5;

    path.moveTo(w * 0.2, 0);
    path.quadraticBezierTo(w * 0.5, -10 + offset, w * 0.8, 0);
    path.quadraticBezierTo(w + 10, h * 0.3, w, h * 0.7);
    path.quadraticBezierTo(w * 0.7, h + 5 - offset, w * 0.3, h);
    path.quadraticBezierTo(-5, h * 0.6, 0, h * 0.3);
    path.quadraticBezierTo(w * 0.1, -5 + offset, w * 0.2, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(BlobPainter oldDelegate) =>
      color != oldDelegate.color ||
      animationValue != oldDelegate.animationValue;
}
