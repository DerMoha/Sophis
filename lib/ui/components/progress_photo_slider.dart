import 'dart:io';
import 'package:flutter/material.dart';

class ProgressPhotoSlider extends StatefulWidget {
  final File beforeImage;
  final File afterImage;

  const ProgressPhotoSlider({
    super.key,
    required this.beforeImage,
    required this.afterImage,
  });

  @override
  State<ProgressPhotoSlider> createState() => _ProgressPhotoSliderState();
}

class _ProgressPhotoSliderState extends State<ProgressPhotoSlider> {
  double _sliderPosition = 0.5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _sliderPosition = (_sliderPosition + details.delta.dx / width).clamp(0.0, 1.0);
            });
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Before image - displayed in background
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    widget.beforeImage,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // After image - clipped horizontally based on slider position
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ClipRect(
                    clipper: _SliderClipper(_sliderPosition),
                    child: Image.file(
                      widget.afterImage,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              // Divider Line
              Positioned(
                left: _sliderPosition * width - 1.5,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  color: Colors.white,
                ),
              ),

              // Draggable Handle Indicator
              Positioned(
                left: _sliderPosition * width - 20,
                top: height / 2 - 20,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.compare_arrows_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
              ),

              // Before Label (Top-Left overlay)
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'BEFORE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              // After Label (Top-Right overlay)
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'AFTER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SliderClipper extends CustomClipper<Rect> {
  final double position;

  const _SliderClipper(this.position);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(position * size.width, 0, size.width, size.height);
  }

  @override
  bool shouldReclip(_SliderClipper oldClipper) => oldClipper.position != position;
}
