import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/supplements_provider.dart';
import '../../services/settings_provider.dart';
import '../theme/app_theme.dart';
import 'organic_components.dart';
import '../screens/supplements_screen.dart';

class SupplementsTodayCard extends StatelessWidget {
  const SupplementsTodayCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    final settings = Provider.of<SettingsProvider>(context);

    if (!settings.showSupplements) {
      return const SizedBox.shrink();
    }

    return Consumer<SupplementsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const SizedBox.shrink();
        }

        final supplements = provider.enabledSupplements;
        final completedIds = provider.getTodayCompletedIds();
        final completedCount = completedIds.length;
        final totalCount = supplements.length;

        // Don't show if no supplements
        if (totalCount == 0) {
          return GlassCard(
            padding: const EdgeInsets.all(20),
            onTap: () => Navigator.push(
              context,
              AppTheme.slideRoute(const SupplementsScreen()),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.medication_liquid_rounded,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('Supplements', style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'No supplements added yet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.add_circle_rounded,
                      size: 18,
                      color: accentColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tap to add your first supplement',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.medication_liquid_rounded,
                      color: accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Supplements', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  // Completion badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: completedCount == totalCount
                          ? accentColor.withValues(alpha: 0.15)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$completedCount/$totalCount',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: completedCount == totalCount
                            ? accentColor
                            : theme.textTheme.bodyMedium?.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Supplements list
              ...supplements.map((supplement) {
                final isCompleted = completedIds.contains(supplement.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SupplementCheckbox(
                    label: supplement.name,
                    isChecked: isCompleted,
                    accentColor: accentColor,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      provider.toggleCompletion(supplement.id);
                    },
                  ),
                );
              }),

              const SizedBox(height: 8),

              // View All button
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  AppTheme.slideRoute(const SupplementsScreen()),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.settings_rounded,
                      size: 16,
                      color: accentColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Manage Supplements',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SupplementCheckbox extends StatefulWidget {
  final String label;
  final bool isChecked;
  final VoidCallback onTap;
  final Color accentColor;

  const _SupplementCheckbox({
    required this.label,
    required this.isChecked,
    required this.onTap,
    required this.accentColor,
  });

  @override
  State<_SupplementCheckbox> createState() => _SupplementCheckboxState();
}

class _SupplementCheckboxState extends State<_SupplementCheckbox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppTheme.animNormal,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AppTheme.springCurve,
      ),
    );

    if (widget.isChecked) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_SupplementCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isChecked != oldWidget.isChecked) {
      if (widget.isChecked) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          // Organic checkbox
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: widget.isChecked ? widget.accentColor : Colors.transparent,
              border: Border.all(
                color: widget.isChecked
                    ? widget.accentColor
                    : theme.colorScheme.outline.withValues(alpha: 0.3),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: widget.isChecked
                ? ScaleTransition(
                    scale: _scaleAnimation,
                    child: const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                decoration: widget.isChecked
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                color: widget.isChecked
                    ? theme.textTheme.bodySmall?.color
                    : theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
