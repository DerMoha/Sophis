import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/providers/nutrition_provider.dart';

/// Keeps feedback usable after the input route or list item is removed.
void showFoodAddedFeedback(BuildContext context, FoodEntry entry) {
  showFoodsAddedFeedback(context, [entry]);
}

void showFoodsAddedFeedback(BuildContext context, List<FoodEntry> entries, {
  void Function(FoodEntry entry)? onUndone,
}) {
  if (entries.isEmpty) return;
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final nutrition = context.read<NutritionProvider>();
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(persist: false, duration: const Duration(seconds: 4),
    content: Text(l10n.added),
    action: SnackBarAction(label: l10n.undo, onPressed: () async {
      try {
        for (final entry in entries) {
          await nutrition.removeFoodEntry(entry.id);
          onUndone?.call(entry);
        }
      } catch (_) {
        if (messenger.mounted) messenger.showSnackBar(SnackBar(persist: false, content: Text(l10n.changeEntryFailed)));
      }
    },),
  ),);
}

/// Captures the original entry in the undo closure, preserving its date and id.
Future<void> deleteEntryWithUndo(
  BuildContext context, {
  required Future<void> Function() remove,
  required Future<void> Function() restore,
  required String label,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await remove();
    if (!messenger.mounted) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(persist: false, duration: const Duration(seconds: 4),
        content: Text(l10n.foodEntryDeleted(label)),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () async {
            try {
              await restore();
            } catch (_) {
              if (!messenger.mounted) return;
              messenger.showSnackBar(
                SnackBar(persist: false, content: Text(l10n.changeEntryFailed)),
              );
            }
          },
        ),
      ),
    );
  } catch (_) {
    if (!messenger.mounted) return;
    messenger.showSnackBar(
      SnackBar(persist: false, content: Text(l10n.changeEntryFailed)),
    );
  }
}
