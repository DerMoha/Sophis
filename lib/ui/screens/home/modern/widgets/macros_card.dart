import 'package:flutter/material.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/nutrition_totals.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/components/organic_components.dart';
import 'package:sophis/ui/screens/macro_details_screen.dart';

/// Macro rings card for the modern home screen.
class MacrosCard extends StatelessWidget {
  final NutritionTotals totals;
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
            value: totals.protein,
            goal: goals.protein,
            color: AppTheme.protein,
            positiveExcess: true,
            excessColor: AppTheme.success,
          ),
          MacroRing(
            label: l10n.carbs,
            value: totals.carbs,
            goal: goals.carbs,
            color: AppTheme.carbs,
          ),
          MacroRing(
            label: l10n.fat,
            value: totals.fat,
            goal: goals.fat,
            color: AppTheme.fat,
          ),
        ],
      ),
    );
  }
}
