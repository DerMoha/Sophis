import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/services/food_intake_controller.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/ui/components/edit_food_entry_dialog.dart';
import 'package:sophis/ui/components/common/ui_primitives.dart';
import 'package:sophis/ui/components/settings/settings_tiles.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/components/organic_components.dart';
import 'package:sophis/ui/theme/animations.dart';
import 'package:sophis/ui/screens/shared/meal_action_helpers.dart';

/// Full-screen detail view for a single meal (breakfast, lunch, etc.)
class MealDetailScreen extends StatelessWidget {
  final DateTime? date;
  final String mealType;
  final String mealTitle;
  final IconData mealIcon;

  const MealDetailScreen({
    super.key,
    this.date,
    required this.mealType,
    required this.mealTitle,
    required this.mealIcon,
  });

  bool get _canAdd => date == null || DateUtils.isSameDay(date, DateTime.now());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Consumer<NutritionProvider>(
      builder: (context, nutrition, _) {
        final entries = date == null
            ? nutrition.getEntriesByMeal(mealType)
            : nutrition
                .getEntriesForDate(date!)
                .where((entry) => entry.meal == mealType)
                .toList();

        var totalCalories = 0.0;
        var totalProtein = 0.0;
        var totalCarbs = 0.0;
        var totalFat = 0.0;
        for (final entry in entries) {
          totalCalories += entry.calories;
          totalProtein += entry.protein;
          totalCarbs += entry.carbs;
          totalFat += entry.fat;
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              mealTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (entries.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: l10n.share,
                  onPressed: () => shareMealEntries(
                    context,
                    entries,
                    title: mealTitle,
                  ),
                ),
            ],
          ),
          body: entries.isEmpty
              ? _buildEmptyState(context, l10n, theme)
              : Column(
                  children: [
                    // Summary card
                    FadeInSlide(
                      index: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Text(
                                    totalCalories.toStringAsFixed(0),
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    ' kcal',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spaceSM2),
                              Wrap(
                                spacing: 16,
                                runSpacing: 12,
                                alignment: WrapAlignment.start,
                                children: [
                                  _MealMacro(
                                    label: l10n.protein,
                                    value: totalProtein,
                                    color: AppTheme.protein,
                                  ),
                                  _MealMacro(
                                    label: l10n.carbs,
                                    value: totalCarbs,
                                    color: AppTheme.carbs,
                                  ),
                                  _MealMacro(
                                    label: l10n.fat,
                                    value: totalFat,
                                    color: AppTheme.fat,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Entries list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _MealEntryCard(
                              entry: entry,
                              mealType: mealType,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
          floatingActionButton: !_canAdd
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _showAddOptions(context),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.add),
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              mealIcon,
              size: 36,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppTheme.spaceLG2),
          Text(
            l10n.noEntries,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    showMealAddOptionsSheet(context, mealType: mealType);
  }
}

/// Opens the same editor from the diary, meal detail or home screen.
Future<void> showFoodEntryEditor(BuildContext context, FoodEntry entry) =>
    _MealEntryCard(entry: entry, mealType: entry.meal)
        ._showEditDialog(context, AppLocalizations.of(context)!);

void showFoodEntryActions(BuildContext context, FoodEntry entry) =>
    _MealEntryCard(entry: entry, mealType: entry.meal)
        ._showQuickActions(context, AppLocalizations.of(context)!);

/// Card for a single food entry with edit controls
class _MealEntryCard extends StatelessWidget {
  final FoodEntry entry;
  final String mealType;

  const _MealEntryCard({
    required this.entry,
    required this.mealType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark
              ? CachedColors.surfaceTintDark06
              : CachedColors.surfaceTintLight04,
        ),
      ),
      child: Column(
        children: [
          // Main content - tappable for quick actions
          InkWell(
            onTap: () => _showQuickActions(context, l10n),
            onLongPress: () => _showQuickActions(context, l10n),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusMD),
              bottom: Radius.circular(AppTheme.radiusMD),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.calories.toStringAsFixed(0)} kcal',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Macro row
                  Row(
                    children: [
                      MacroChip(
                        label: 'P',
                        value: entry.protein,
                        color: AppTheme.protein,
                      ),
                      const SizedBox(width: 12),
                      MacroChip(
                        label: 'C',
                        value: entry.carbs,
                        color: AppTheme.carbs,
                      ),
                      const SizedBox(width: 12),
                      MacroChip(
                        label: 'F',
                        value: entry.fat,
                        color: AppTheme.fat,
                      ),
                      const Spacer(),
                      Icon(
                        Icons.more_horiz,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _adjustPortion(BuildContext context, double factor) {
    final nutrition = context.read<NutritionProvider>();
    final updatedEntry = entry.scaledBy(factor);
    nutrition.updateFoodEntry(updatedEntry);
  }

  void _showQuickActions(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with entry info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: theme.dividerColor,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${entry.calories.toStringAsFixed(0)} kcal',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PortionButton(
                        label: '-25%',
                        onTap: () {
                          Navigator.pop(ctx);
                          _adjustPortion(context, 0.75);
                        },
                      ),
                      _PortionButton(
                        label: '-10%',
                        onTap: () {
                          Navigator.pop(ctx);
                          _adjustPortion(context, 0.9);
                        },
                      ),
                      _PortionButton(
                        label: '+10%',
                        onTap: () {
                          Navigator.pop(ctx);
                          _adjustPortion(context, 1.1);
                        },
                      ),
                      _PortionButton(
                        label: '+25%',
                        onTap: () {
                          Navigator.pop(ctx);
                          _adjustPortion(context, 1.25);
                        },
                      ),
                    ],
                  ),
                ),
                ActionTile(
                  icon: Icons.delete_outline,
                  iconColor: theme.colorScheme.error,
                  title: l10n.delete,
                  textColor: theme.colorScheme.error,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteConfirmation(context, l10n);
                  },
                ),
                // Actions
                ActionTile(
                  icon: Icons.swap_horiz_outlined,
                  title: l10n.moveTo,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showMoveToMealDialog(context, l10n);
                  },
                ),
                ActionTile(
                  icon: Icons.copy_outlined,
                  title: entry.timestamp.year == DateTime.now().year &&
                          entry.timestamp.month == DateTime.now().month &&
                          entry.timestamp.day == DateTime.now().day
                      ? l10n.duplicate
                      : l10n.copyEntryToToday,
                  onTap: () {
                    Navigator.pop(ctx);
                    _duplicateEntry(context, l10n);
                  },
                ),
                ActionTile(
                  icon: Icons.edit_outlined,
                  title: l10n.editEntry,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditDialog(context, l10n);
                  },
                ),
                ActionTile(
                  icon: Icons.bookmark_add_outlined,
                  title: l10n.saveToMyFoods,
                  onTap: () {
                    Navigator.pop(ctx);
                    _saveToMyFoods(context, l10n);
                  },
                ),
                ActionTile(
                  icon: Icons.share_outlined,
                  title: l10n.share,
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareEntry(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMoveToMealDialog(BuildContext context, AppLocalizations l10n) {
    final meals = context
        .read<SettingsProvider>()
        .mealTypes
        .where((configuredMeal) => configuredMeal.id != mealType)
        .toList();

    if (meals.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.moveTo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: meals.map((meal) {
            return ListTile(
              leading: Icon(meal.icon, color: meal.color),
              title: Text(meal.displayName(l10n)),
              onTap: () {
                Navigator.pop(ctx);
                final nutrition = context.read<NutritionProvider>();
                final updatedEntry = entry.copyWith(meal: meal.id);
                nutrition.updateFoodEntry(updatedEntry);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.movedTo(meal.displayName(l10n)))),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _duplicateEntry(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final nutrition = context.read<NutritionProvider>();
    await nutrition.duplicateFoodEntry(entry);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.entryDuplicated)),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final updatedEntry = await showDialog<FoodEntry>(
      context: context,
      builder: (_) => EditFoodEntryDialog(entry: entry),
    );
    if (updatedEntry == null || !context.mounted) return;
    await context.read<NutritionProvider>().updateFoodEntry(updatedEntry);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.entrySaved)),
    );
  }

  Future<void> _saveToMyFoods(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final result =
        await context.read<FoodIntakeController>().saveEntryAsCustomFood(entry);

    if (!context.mounted) return;

    switch (result) {
      case Success():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.customFoodSaved)),
        );
      case Failure(message: final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
    }
  }

  void _shareEntry(BuildContext context) {
    shareMealEntries(context, [entry]);
  }

  void _showDeleteConfirmation(BuildContext context, AppLocalizations l10n) {
    deleteFoodEntryWithUndo(context, entry: entry);
  }
}

/// Quick portion adjustment button
class _PortionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PortionButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncrease = label.startsWith('+');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: (isIncrease ? AppTheme.success : AppTheme.warning)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusXS),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isIncrease ? AppTheme.success : AppTheme.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _MealMacro extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MealMacro({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ${value.toStringAsFixed(0)}g',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
