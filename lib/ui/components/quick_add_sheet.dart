import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/services/food_entry_factory.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/components/portion_picker_sheet.dart';
import 'package:sophis/ui/screens/add_food_screen.dart';
import 'package:sophis/ui/screens/ai_food_camera_screen.dart';
import 'package:sophis/ui/screens/barcode_scanner_screen.dart';
import 'package:sophis/ui/screens/food_search_screen.dart';

Future<void> showQuickAddSheet(
  BuildContext context, {
  required String mealType,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
    ),
    builder: (sheetContext) => SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.75,
        builder: (scrollContext, scrollController) {
          return _QuickAddContent(
            mealType: mealType,
            scrollController: scrollController,
            sheetContext: sheetContext,
          );
        },
      ),
    ),
  );
}

class _QuickAddContent extends StatelessWidget {
  final String mealType;
  final ScrollController scrollController;
  final BuildContext sheetContext;

  const _QuickAddContent({
    required this.mealType,
    required this.scrollController,
    required this.sheetContext,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final recentFoods =
        context.watch<NutritionProvider>().getRecentFoodsForMeal(mealType);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        if (recentFoods.isNotEmpty) ...[
          _buildQuickAddSection(context, l10n, theme, recentFoods),
          const SizedBox(height: 8),
          Divider(
            indent: 20,
            endIndent: 20,
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ],
        _buildActionsSection(context, l10n, theme),
      ],
    );
  }

  Widget _buildQuickAddSection(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    List<FoodItem> foods,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.schedule_outlined,
                size: AppTheme.iconSM,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.recentlyUsed,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: foods.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppTheme.spaceSM),
            itemBuilder: (context, index) {
              return _RecentFoodChip(
                food: foods[index],
                mealType: mealType,
                sheetContext: sheetContext,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionsSection(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Column(
      children: [
        _ActionTile(
          icon: Icons.edit_outlined,
          label: l10n.manualEntry,
          color: theme.colorScheme.primary,
          onTap: () {
            Navigator.pop(sheetContext);
            Navigator.push(
              context,
              AppTheme.slideRoute(AddFoodScreen(meal: mealType)),
            );
          },
        ),
        _ActionTile(
          icon: Icons.search_outlined,
          label: l10n.searchFood,
          color: theme.colorScheme.primary,
          onTap: () {
            Navigator.pop(sheetContext);
            Navigator.push(
              context,
              AppTheme.slideRoute(FoodSearchScreen(meal: mealType)),
            );
          },
        ),
        _ActionTile(
          icon: Icons.qr_code_scanner_outlined,
          label: l10n.scanBarcode,
          color: theme.colorScheme.primary,
          onTap: () {
            Navigator.pop(sheetContext);
            Navigator.push(
              context,
              AppTheme.slideRoute(BarcodeScannerScreen(meal: mealType)),
            );
          },
        ),
        _ActionTile(
          icon: Icons.auto_awesome_outlined,
          label: l10n.aiRecognition,
          color: theme.colorScheme.primary,
          onTap: () {
            Navigator.pop(sheetContext);
            Navigator.push(
              context,
              AppTheme.slideRoute(AIFoodCameraScreen(meal: mealType)),
            );
          },
        ),
      ],
    );
  }
}

class _RecentFoodChip extends StatelessWidget {
  final FoodItem food;
  final String mealType;
  final BuildContext sheetContext;

  const _RecentFoodChip({
    required this.food,
    required this.mealType,
    required this.sheetContext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final calories = food.caloriesPer100g;

    return GestureDetector(
      onTap: () {
        Navigator.pop(sheetContext);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => PortionPickerSheet(
            item: food,
            meal: mealType,
            onAdd: (grams) {
              final entry = FoodEntryFactory.fromFoodItem(
                item: food,
                grams: grams,
                meal: mealType,
              );
              final provider = context.read<NutritionProvider>();
              provider.addFoodEntry(entry);
              provider.addRecentFood(food, meal: mealType);
              Navigator.pop(context);
            },
          ),
        );
      },
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              food.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${calories.toStringAsFixed(0)} kcal',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusXS),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        title: Text(label),
        trailing: Icon(
          Icons.chevron_right,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }
}
