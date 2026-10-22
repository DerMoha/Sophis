import 'package:flutter/material.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/ui/components/common/entry_feedback.dart';

/// Repeats the last breakfast/lunch/etc. without opening the meal screen.
class RepeatMealButton extends StatefulWidget {
  final String meal;
  const RepeatMealButton({super.key, required this.meal});

  @override
  State<RepeatMealButton> createState() => _RepeatMealButtonState();
}

class _RepeatMealButtonState extends State<RepeatMealButton> {
  bool _isSaving = false;

  Future<void> _repeat() async {
    if (_isSaving) return;
    final nutrition = context.read<NutritionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    try {
      final source = List<FoodEntry>.of(nutrition.getLastLoggedMealEntries(meal: widget.meal));
      if (source.isEmpty) return;
      final confirmed = await confirmMealCopy(context, source, title: l10n.repeatLastMeal);
      if (confirmed != true || !mounted) return;
      final entries = await nutrition.repeatEntries(source);
      if (mounted) showFoodsAddedFeedback(context, entries);
    } catch (_) {
      if (messenger.mounted) messenger.showSnackBar(SnackBar(content: Text(l10n.saveEntryFailed)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Consumer<NutritionProvider>(builder: (context, nutrition, _) {
    if (nutrition.getLastLoggedMealEntries(meal: widget.meal).isEmpty) return const SizedBox.shrink();
    return IconButton(
      tooltip: AppLocalizations.of(context)!.repeatLastMeal,
      onPressed: _isSaving ? null : _repeat,
      icon: const Icon(Icons.replay_outlined),
    );
  },);
}

Future<bool?> confirmMealCopy(BuildContext context, List<FoodEntry> source, {required String title}) {
  final l10n = AppLocalizations.of(context)!;
  return showModalBottomSheet<bool>(
        context: context, isScrollControlled: true, useSafeArea: true, showDragHandle: true,
        builder: (sheetContext) => SingleChildScrollView(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            Text(DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(source.first.timestamp)),
            const SizedBox(height: 12),
            for (final entry in source) ListTile(contentPadding: EdgeInsets.zero,
              title: Text(entry.name), subtitle: Text('${entry.calories.toStringAsFixed(0)} kcal'),),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => Navigator.pop(sheetContext, true), child: Text(l10n.add)),
            TextButton(onPressed: () => Navigator.pop(sheetContext, false), child: Text(l10n.cancel)),
          ],),
        ),),
      );
}
