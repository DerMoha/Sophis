import 'package:flutter/material.dart';
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
      final entries = await nutrition.repeatLastMeal(meal: widget.meal);
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
