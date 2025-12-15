import 'package:flutter/material.dart';

/// Animated progress indicator with smooth value transitions
class AnimatedProgressBar extends StatelessWidget {
  final double value;
  final Color? backgroundColor;
  final Color? valueColor;
  final double height;
  final BorderRadius? borderRadius;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.backgroundColor,
    this.valueColor,
    this.height = 8,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.surfaceContainerHighest;
    final fg = valueColor ?? theme.colorScheme.primary;
    final radius = borderRadius ?? BorderRadius.circular(height / 2);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                width: constraints.maxWidth * value.clamp(0.0, 1.0),
                decoration: BoxDecoration(
                  color: fg,
                  borderRadius: radius,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Staggered fade-in animation for list items
class FadeInSlide extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  const FadeInSlide({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 300),
    this.offset = const Offset(0, 20),
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Staggered delay based on index
    Future.delayed(widget.delay * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: _slideAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Animated counter that smoothly ticks up/down
class AnimatedCounter extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final String suffix;
  final int decimals;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.suffix = '',
    this.decimals = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: value, end: value),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(
          '${animatedValue.toStringAsFixed(decimals)}$suffix',
          style: style,
        );
      },
    );
  }
}

/// Pulsing animation for attention-grabbing elements
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const PulseAnimation({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.enabled) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulseAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.enabled) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_controller.value * 0.05),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
