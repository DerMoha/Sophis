import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../models/food_entry.dart';
import '../../../../models/shareable_meal.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/organic_components.dart';
import '../../../../services/nutrition_provider.dart';
import '../../../add_food_screen.dart';
import '../../../food_search_screen.dart';
import '../../../barcode_scanner_screen.dart';
import '../../../ai_food_camera_screen.dart';
import '../../../meal_detail_screen.dart';
import '../../../share_meal_screen.dart';

/// A meal section (e.g., Breakfast, Lunch) with food entries.
class MealSection extends StatelessWidget {
  final String mealType;
  final String title;
  final IconData icon;
  final Color? color;
  final bool showMacros;

  const MealSection({
    super.key,
    required this.mealType,
    required this.title,
    required this.icon,
    this.color,
    required this.showMacros,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<NutritionProvider, List<FoodEntry>>(
      selector: (_, n) => n.getEntriesByMeal(mealType),
      builder: (context, entries, _) {
        return _MealSectionContent(
          mealType: mealType,
          title: title,
          icon: icon,
          color: color,
          showMacros: showMacros,
          entries: entries,
        );
      },
    );
  }
}

class _MealSectionContent extends StatelessWidget {
  final String mealType;
  final String title;
  final IconData icon;
  final Color? color;
  final bool showMacros;
  final List<FoodEntry> entries;

  const _MealSectionContent({
    required this.mealType,
    required this.title,
    required this.icon,
    this.color,
    required this.showMacros,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final total = entries.fold(0.0, (sum, e) => sum + e.calories);
    final totalProtein = entries.fold(0.0, (sum, e) => sum + e.protein);
    final totalCarbs = entries.fold(0.0, (sum, e) => sum + e.carbs);
    final totalFat = entries.fold(0.0, (sum, e) => sum + e.fat);

    return MealCard(
      title: title,
      icon: icon,
      calories: total,
      color: color,
      showMacros: showMacros,
      protein: totalProtein,
      carbs: totalCarbs,
      fat: totalFat,
      onHeaderTap: () => Navigator.push(
        context,
        AppTheme.slideRoute(MealDetailScreen(
          mealType: mealType,
          mealTitle: title,
          mealIcon: icon,
        )),
      ),
      addMenu: _buildAddMenu(context, l10n, theme, entries),
      entries: entries.isEmpty
          ? [_buildEmptyState(theme, l10n)]
          : entries.map((entry) => _buildEntryTile(context, l10n, entry)).toList(),
    );
  }

  Widget _buildAddMenu(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    List<FoodEntry> entries,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (entries.isNotEmpty)
          IconButton(
            icon: Icon(
              Icons.share_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: () => _shareMeal(context, entries),
            tooltip: l10n.share,
          ),
        PopupMenuButton<String>(
          icon: Icon(Icons.add_circle_outline, color: theme.colorScheme.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
          onSelected: (value) => _handleAction(context, value),
          itemBuilder: (_) => [
            _buildPopupItem(Icons.edit_outlined, l10n.manualEntry, 'manual'),
            _buildPopupItem(Icons.search_outlined, l10n.searchFood, 'search'),
            _buildPopupItem(Icons.qr_code_scanner_outlined, l10n.scanBarcode, 'barcode'),
            _buildPopupItem(Icons.auto_awesome_outlined, l10n.aiRecognition, 'ai'),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupItem(IconData icon, String label, String value) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Text(
        l10n.noEntries,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildEntryTile(BuildContext context, AppLocalizations l10n, FoodEntry entry) {
    return FoodEntryTile(
      key: ValueKey(entry.id),
      name: entry.name,
      calories: entry.calories,
      protein: entry.protein,
      carbs: entry.carbs,
      fat: entry.fat,
      onLongPress: () => _showEntryOptions(context, l10n, entry),
    );
  }

  void _handleAction(BuildContext context, String action) {
    Widget screen;
    switch (action) {
      case 'manual':
        screen = AddFoodScreen(meal: mealType);
        break;
      case 'search':
        screen = FoodSearchScreen(meal: mealType);
        break;
      case 'barcode':
        screen = BarcodeScannerScreen(meal: mealType);
        break;
      case 'ai':
        screen = AIFoodCameraScreen(meal: mealType);
        break;
      default:
        return;
    }
    Navigator.push(context, AppTheme.slideRoute(screen));
  }

  void _shareMeal(BuildContext context, List<FoodEntry> entries) {
    final meal = ShareableMeal.fromFoodEntries(entries, title: title);
    Navigator.push(context, AppTheme.slideRoute(ShareMealScreen(meal: meal)));
  }

  void _showEntryOptions(BuildContext context, AppLocalizations l10n, FoodEntry entry) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.share_outlined, color: theme.colorScheme.primary),
              title: Text(l10n.share),
              onTap: () {
                Navigator.pop(ctx);
                _shareSingleItem(context, entry);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              title: Text(l10n.delete, style: TextStyle(color: theme.colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirmation(context, l10n, entry);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _shareSingleItem(BuildContext context, FoodEntry entry) {
    final meal = ShareableMeal.fromFoodEntries([entry]);
    Navigator.push(context, AppTheme.slideRoute(ShareMealScreen(meal: meal)));
  }

  void _showDeleteConfirmation(
    BuildContext context,
    AppLocalizations l10n,
    FoodEntry entry,
  ) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteConfirmation(entry.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              context.read<NutritionProvider>().removeFoodEntry(entry.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}
