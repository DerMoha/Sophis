import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../theme/app_theme.dart';
import 'organic_components.dart';

class FoodSearchResultTile extends StatelessWidget {
  final FoodItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isCustomFood;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const FoodSearchResultTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.isCustomFood = false,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceXS,
      ),
      padding: const EdgeInsets.all(AppTheme.spaceSM),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        children: [
          if (isCustomFood)
            _CustomFoodIcon()
          else
            _ProductImage(imageUrl: item.imageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCustomFood)
                  Text(
                    'My Foods',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else if (item.brand != null && item.brand!.isNotEmpty)
                  Text(
                    item.brand!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  item.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                _MacroChips(item: item),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (onFavoriteToggle != null)
            _FavoriteButton(
              isFavorite: isFavorite,
              onTap: onFavoriteToggle!,
            ),
          _CalorieBadge(calories: item.caloriesPer100g),
        ],
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onTap;

  const _FavoriteButton({
    required this.isFavorite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(
          isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
          color: isFavorite ? AppTheme.carbs : Theme.of(context).disabledColor,
          size: 28,
        ),
      ),
    );
  }
}

class _CustomFoodIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color:
            theme.colorScheme.secondary.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Center(
        child: Icon(
          Icons.bookmark,
          color: theme.colorScheme.secondary,
          size: 28,
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? imageUrl;

  const _ProductImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _PlaceholderIcon(),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
            )
          : const _PlaceholderIcon(),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  const _PlaceholderIcon();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Icon(
        Icons.restaurant_outlined,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
        size: 24,
      ),
    );
  }
}

class _MacroChips extends StatelessWidget {
  final FoodItem item;

  const _MacroChips({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MacroChip(
          label: 'P',
          value: item.proteinPer100g,
          color: AppTheme.protein,
        ),
        const SizedBox(width: 6),
        _MacroChip(
          label: 'C',
          value: item.carbsPer100g,
          color: AppTheme.carbs,
        ),
        const SizedBox(width: 6),
        _MacroChip(
          label: 'F',
          value: item.fatPer100g,
          color: AppTheme.fat,
        ),
      ],
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
      ),
      child: Text(
        '$label: ${value.toStringAsFixed(0)}g',
        style: theme.textTheme.labelSmall?.copyWith(
          color: isDark
              ? color.withValues(alpha: 0.9)
              : color.withValues(alpha: 0.8),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _CalorieBadge extends StatelessWidget {
  final double calories;

  const _CalorieBadge({required this.calories});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSM,
        vertical: AppTheme.spaceXS + 2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            calories.toStringAsFixed(0),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'kcal',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
