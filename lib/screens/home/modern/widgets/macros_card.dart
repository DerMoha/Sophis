import 'package:flutter/material.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../models/nutrition_goals.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/organic_components.dart';
import '../../../macro_details_screen.dart';

/// Macro rings card for the modern home screen.
class MacrosCard extends StatelessWidget {
  final Map<String, double> totals;
  final NutritionGoals goals;

  const MacrosCard({
    super.key,
    required this.totals,
    required this.goals,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return GlassCard(
      onTap: () => Navigator.push(
        context,
        AppTheme.slideRoute(MacroDetailsScreen(totals: totals, goals: goals)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          MacroRing(
            label: l10n.protein,
            value: totals['protein']!,
            goal: goals.protein,
            color: AppTheme.protein,
            positiveExcess: true,
            excessColor: AppTheme.success,
          ),
          MacroRing(
            label: l10n.carbs,
            value: totals['carbs']!,
            goal: goals.carbs,
            color: AppTheme.carbs,
          ),
          MacroRing(
            label: l10n.fat,
            value: totals['fat']!,
            goal: goals.fat,
            color: AppTheme.fat,
          ),
        ],
      ),
    );
  }
}
