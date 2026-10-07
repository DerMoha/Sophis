import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
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
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(l10n.quickAddAdded(entry.name)),
      action: SnackBarAction(
        label: l10n.undo,
        onPressed: () => context.read<NutritionProvider>().removeFoodEntry(
              entry.id,
            ),
      ),
    ),
  );
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
      case Failure<FoodEntry>(message: final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
    }
  }

  Future<bool> _confirmCameraAccess(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.cameraAccessTitle),
            content: Text(l10n.cameraAccessBarcodeExplanation),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.continueLabel),
              ),
            ],
          ),
        ) ??
        false;
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

  Widget _buildActionsSection(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Text(l10n.addFood, style: theme.textTheme.titleLarge),
        ),
        _ActionTile(
          icon: Icons.search_outlined,
          label: l10n.searchFood,
          color: theme.colorScheme.primary,
          onTap: () {
            Navigator.pop(widget.sheetContext);
            Navigator.push(
              context,
              AppTheme.slideRoute(FoodSearchScreen(meal: widget.mealType)),
            );
          },
        ),
        _ActionTile(
          icon: Icons.qr_code_scanner_outlined,
          label: l10n.scanBarcode,
          color: theme.colorScheme.primary,
          onTap: () async {
            if (!await _confirmCameraAccess(context)) return;
            if (!context.mounted) return;
            Navigator.pop(widget.sheetContext);
            Navigator.push(
              context,
              AppTheme.slideRoute(BarcodeScannerScreen(meal: widget.mealType)),
            );
          },
        ),
        _ActionTile(
          icon: Icons.document_scanner_outlined,
          label: l10n.nutritionLabelScannerTitle,
          color: theme.colorScheme.primary,
          onTap: () {
            Navigator.pop(widget.sheetContext);
            Navigator.push(
              context,
              AppTheme.slideRoute(
                NutritionLabelScannerScreen(meal: widget.mealType),
              ),
            );
          },
        ),
        _ActionTile(
          icon: Icons.edit_outlined,
          label: l10n.manualEntry,
          color: theme.colorScheme.primary,
          onTap: () {
            Navigator.pop(widget.sheetContext);
            Navigator.push(
              context,
              AppTheme.slideRoute(AddFoodScreen(meal: widget.mealType)),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
          child: Text(
            l10n.optionalAi,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _ActionTile(
          icon: Icons.auto_awesome_outlined,
          label: l10n.aiRecognition,
          color: theme.colorScheme.primary,
          onTap: () {
            Navigator.pop(widget.sheetContext);
            Navigator.push(
              context,
              AppTheme.slideRoute(AIFoodCameraScreen(meal: widget.mealType)),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            l10n.aiCloudNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
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
