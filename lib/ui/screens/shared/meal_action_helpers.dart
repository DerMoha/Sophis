import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/shareable_meal.dart';
import 'package:sophis/services/nutrition_provider.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/screens/add_food_screen.dart';
import 'package:sophis/ui/screens/ai_food_camera_screen.dart';
import 'package:sophis/ui/screens/barcode_scanner_screen.dart';
import 'package:sophis/ui/screens/food_search_screen.dart';
import 'package:sophis/ui/screens/share_meal_screen.dart';

void handleMealAddAction(
  BuildContext context, {
  required String mealType,
  required String action,
}) {
  late final Widget screen;

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

void shareMealEntries(
  BuildContext context,
  List<FoodEntry> entries, {
  String? title,
}) {
  final meal = ShareableMeal.fromFoodEntries(entries, title: title);
  Navigator.push(context, AppTheme.slideRoute(ShareMealScreen(meal: meal)));
}

Future<void> showMealAddOptionsSheet(
  BuildContext context, {
  required String mealType,
}) {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);

  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MealActionTile(
            icon: Icons.edit_outlined,
            label: l10n.manualEntry,
            color: theme.colorScheme.primary,
            onTap: () {
              Navigator.pop(sheetContext);
              handleMealAddAction(
                context,
                mealType: mealType,
                action: 'manual',
              );
            },
          ),
          _MealActionTile(
            icon: Icons.search_outlined,
            label: l10n.searchFood,
            color: theme.colorScheme.primary,
            onTap: () {
              Navigator.pop(sheetContext);
              handleMealAddAction(
                context,
                mealType: mealType,
                action: 'search',
              );
            },
          ),
          _MealActionTile(
            icon: Icons.qr_code_scanner_outlined,
            label: l10n.scanBarcode,
            color: theme.colorScheme.primary,
            onTap: () {
              Navigator.pop(sheetContext);
              handleMealAddAction(
                context,
                mealType: mealType,
                action: 'barcode',
              );
            },
          ),
          _MealActionTile(
            icon: Icons.auto_awesome_outlined,
            label: l10n.aiRecognition,
            color: theme.colorScheme.primary,
            onTap: () {
              Navigator.pop(sheetContext);
              handleMealAddAction(
                context,
                mealType: mealType,
                action: 'ai',
              );
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> showDeleteFoodEntryConfirmation(
  BuildContext context, {
  required FoodEntry entry,
}) {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.delete),
      content: Text(l10n.deleteConfirmation(entry.name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            context.read<NutritionProvider>().removeFoodEntry(entry.id);
            Navigator.pop(dialogContext);
          },
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
          ),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
}

class _MealActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MealActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      onTap: onTap,
    );
  }
}
