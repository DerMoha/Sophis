import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// Displays the calorie goal with visual indicator when exercise has boosted it.
class BoostedGoalDisplay extends StatefulWidget {
  final double baseGoal;
  final double effectiveGoal;
  final double burnedCalories;

  const BoostedGoalDisplay({
    super.key,
    required this.baseGoal,
    required this.effectiveGoal,
    required this.burnedCalories,
  });

  @override
  State<BoostedGoalDisplay> createState() => _BoostedGoalDisplayState();
}

class _BoostedGoalDisplayState extends State<BoostedGoalDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  bool get _isBoosted => widget.burnedCalories > 0;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    if (_isBoosted) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(BoostedGoalDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isBoosted && !_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
    } else if (!_isBoosted && _glowController.isAnimating) {
      _glowController.stop();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_isBoosted) {
      return Text(
        '/ ${widget.baseGoal.toStringAsFixed(0)}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGoalRow(theme),
            const SizedBox(height: 2),
            _buildBonusBadge(theme),
          ],
        );
      },
    );
  }

  Widget _buildGoalRow(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: AppTheme.fire.withValues(alpha: 0.3 * _glowAnimation.value),
            blurRadius: 8 * _glowAnimation.value,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.baseGoal.toStringAsFixed(0),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              decoration: TextDecoration.lineThrough,
              decorationColor:
                  theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_forward,
            size: 8,
            color: AppTheme.fire.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          Text(
            '/ ${widget.effectiveGoal.toStringAsFixed(0)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.fire,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBonusBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.fire.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.fire.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 10,
            color: AppTheme.fire,
          ),
          const SizedBox(width: 2),
          Text(
            '+${widget.burnedCalories.toStringAsFixed(0)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.fire,
              fontWeight: FontWeight.w600,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
