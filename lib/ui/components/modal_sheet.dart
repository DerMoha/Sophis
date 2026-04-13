import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ModalSheetSurface extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final bool useSafeArea;
  final bool useAnimatedInsets;

  const ModalSheetSurface({
    super.key,
    required this.child,
    this.backgroundColor,
    this.useSafeArea = true,
    this.useAnimatedInsets = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom);

    Widget content = child;
    if (useAnimatedInsets) {
      content = AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: bottomInset,
        child: content,
      );
    } else {
      content = Padding(padding: bottomInset, child: content);
    }

    if (useSafeArea) {
      content = SafeArea(top: false, child: content);
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: content,
    );
  }
}

class ModalSheetHandle extends StatelessWidget {
  final Color? color;

  const ModalSheetHandle({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.outline.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
      ),
    );
  }
}

class ModalSheetHeader extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final double iconSize;
  final double iconBoxSize;
  final String title;
  final Widget? trailing;
  final bool showCloseButton;
  final EdgeInsetsGeometry padding;

  const ModalSheetHeader({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.iconSize = 22,
    this.iconBoxSize = 40,
    this.trailing,
    this.showCloseButton = true,
    this.padding = const EdgeInsets.fromLTRB(24, 20, 16, 0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leadingColor = iconColor ?? theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: iconBoxSize,
                    height: iconBoxSize,
                    decoration: BoxDecoration(
                      color: leadingColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    child: Icon(
                      icon,
                      color: leadingColor,
                      size: iconSize,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.headlineSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
          if (showCloseButton) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                ),
                child: const Icon(Icons.close, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ],
      ),
    );
  }
}
