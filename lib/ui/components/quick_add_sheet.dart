import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/ui/components/common/entry_feedback.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/services/food_intake_controller.dart';
import 'package:sophis/services/nutrition/food_log_controller.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/components/portion_picker_sheet.dart';
import 'package:sophis/ui/screens/add_food_screen.dart';
import 'package:sophis/ui/screens/ai_food_camera_screen.dart';
import 'package:sophis/ui/screens/barcode_scanner_screen.dart';
import 'package:sophis/ui/screens/food_search_screen.dart';
import 'package:sophis/ui/screens/nutrition_label_scanner_screen.dart';

Future<void> showQuickAddSheet(
  BuildContext context, {
  required String mealType,
}) async {
  final entry = await showModalBottomSheet<FoodEntry>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
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
  if (entry == null || !context.mounted) return;
  showFoodAddedFeedback(context, entry);
}

class _QuickAddContent extends StatefulWidget {
  final String mealType;
  final ScrollController scrollController;
  final BuildContext sheetContext;

  const _QuickAddContent({
    required this.mealType,
    required this.scrollController,
    required this.sheetContext,
  });

  @override
  State<_QuickAddContent> createState() => _QuickAddContentState();
}

class _QuickAddContentState extends State<_QuickAddContent> {
  String? _loggingFoodId;

  Future<void> _logRecentFood(FoodItem food) async {
    if (_loggingFoodId != null) return;
    setState(() => _loggingFoodId = food.id);
    final selection = FoodLogController.defaultPortionFor(food);
    final result = await context.read<FoodIntakeController>().logFoodItem(
          item: food,
          selection: selection,
          meal: widget.mealType,
        );
    if (!mounted) return;
    setState(() => _loggingFoodId = null);
    switch (result) {
      case Success<FoodEntry>(value: final entry):
        if (!widget.sheetContext.mounted) return;
        Navigator.pop(widget.sheetContext, entry);
      case Failure<FoodEntry>():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.saveEntryFailed),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final recentFoods = context
        .watch<NutritionProvider>()
        .getRecentFoodsForMeal(widget.mealType);

    return ListView(
      controller: widget.scrollController,
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
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppTheme.spaceSM),
            itemBuilder: (context, index) {
              return _RecentFoodChip(
                food: foods[index],
                isLogging: _loggingFoodId == foods[index].id,
                onLog: _logRecentFood,
                onEdit: () {
                  Navigator.pop(widget.sheetContext);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => PortionPickerSheet(
                      item: foods[index],
                      meal: widget.mealType,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _open(Widget screen) {
    Navigator.pop(widget.sheetContext);
    Navigator.push(context, AppTheme.slideRoute(screen));
  }

  Widget _buildActionsSection(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Text(l10n.addFood, style: theme.textTheme.titleLarge),
          ),
          _SearchEntryTile(
            label: l10n.searchFood,
            onTap: () => _open(FoodSearchScreen(meal: widget.mealType)),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _CaptureTile(
                    icon: Icons.qr_code_scanner_outlined,
                    label: l10n.addFoodBarcode,
                    semanticLabel: l10n.scanBarcode,
                    onTap: () =>
                        _open(BarcodeScannerScreen(meal: widget.mealType)),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSM),
                Expanded(
                  child: _CaptureTile(
                    icon: Icons.document_scanner_outlined,
                    label: l10n.addFoodNutritionLabel,
                    semanticLabel: l10n.nutritionLabelScannerTitle,
                    onTap: () => _open(
                      NutritionLabelScannerScreen(meal: widget.mealType),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSM),
                Expanded(
                  child: _CaptureTile(
                    icon: Icons.camera_alt_outlined,
                    label: l10n.addFoodPhoto,
                    semanticLabel: l10n.photographFood,
                    badge: l10n.addFoodPhotoAiBadge,
                    onTap: () =>
                        _open(AIFoodCameraScreen(meal: widget.mealType)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.aiCloudNote,
              textAlign: TextAlign.end,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: () => _open(AddFoodScreen(meal: widget.mealType)),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(l10n.manualEntry),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentFoodChip extends StatelessWidget {
  final FoodItem food;
  final bool isLogging;
  final Future<void> Function(FoodItem food) onLog;
  final VoidCallback onEdit;

  const _RecentFoodChip({
    required this.food,
    required this.isLogging,
    required this.onLog,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selection = FoodLogController.defaultPortionFor(food);
    final calories = food.calculateForSelection(selection).calories;
    final amount = selection.amount == selection.amount.roundToDouble()
        ? selection.amount.toStringAsFixed(0)
        : selection.amount.toStringAsFixed(1);

    return GestureDetector(
      onTap: isLogging ? null : () => onLog(food),
      onLongPress: isLogging ? null : onEdit,
      child: Container(
        width: 142,
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$amount ${selection.unit.symbol} · ${calories.toStringAsFixed(0)} kcal',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  isLogging ? Icons.hourglass_top : Icons.bolt_outlined,
                  size: 12,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    isLogging
                        ? AppLocalizations.of(context)!.quickAddAdding
                        : AppLocalizations.of(context)!
                            .quickAddTapToAddHoldToEdit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchEntryTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SearchEntryTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String semanticLabel;
  final String? badge;
  final VoidCallback onTap;

  const _CaptureTile({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Badge(
                  isLabelVisible: badge != null,
                  label: badge == null ? null : Text(badge!),
                  backgroundColor: theme.colorScheme.tertiary,
                  textColor: theme.colorScheme.onTertiary,
                  child: Icon(icon, size: 28, color: color),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
