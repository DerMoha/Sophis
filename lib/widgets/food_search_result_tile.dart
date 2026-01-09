import 'package:flutter/material.dart';
import '../models/food_item.dart';
import 'organic_components.dart';

/// A tile widget for displaying food search results
class FoodSearchResultTile extends StatelessWidget {
  final FoodItem item;
  final VoidCallback onTap;

  const FoodSearchResultTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          // Product Image
          _ProductImage(imageUrl: item.imageUrl),
          const SizedBox(width: 12),

          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand (if available)
                if (item.brand != null && item.brand!.isNotEmpty)
                  Text(
                    item.brand!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                // Product Name
                Text(
                  item.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Macro chips
                _MacroChips(item: item),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Calories badge
          _CalorieBadge(calories: item.caloriesPer100g),
        ],
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
        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _PlaceholderIcon(),
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
          : _PlaceholderIcon(),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Icon(
        Icons.restaurant_outlined,
        color: theme.colorScheme.onSurface.withOpacity(0.3),
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
          color: Colors.blue,
        ),
        const SizedBox(width: 6),
        _MacroChip(
          label: 'C',
          value: item.carbsPer100g,
          color: Colors.orange,
        ),
        const SizedBox(width: 6),
        _MacroChip(
          label: 'F',
          value: item.fatPer100g,
          color: Colors.purple,
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
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: ${value.toStringAsFixed(0)}g',
        style: theme.textTheme.labelSmall?.copyWith(
          color: isDark ? color.withOpacity(0.9) : color.withOpacity(0.8),
          fontWeight: FontWeight.w500,
          fontSize: 10,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(10),
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
              color: theme.colorScheme.primary.withOpacity(0.7),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
