import 'package:flutter/material.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/nutrition_totals.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/components/organic_components.dart';
import 'package:sophis/ui/screens/macro_details_screen.dart';

/// Macro rings card for the modern home screen.
class MacrosCard extends StatelessWidget {
  final bool embedded;
  final NutritionTotals totals;
  final NutritionGoals goals;

  const MacrosCard({
    super.key,
    this.embedded = false,
    required this.totals,
    required this.goals,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    final rings = <Widget>[
      MacroRing(
        size: largeText ? 80 : 56,
        label: l10n.protein,
        value: totals.protein,
        goal: goals.protein,
        color: AppTheme.protein,
        excessColor: AppTheme.success,
      ),
      MacroRing(
        size: largeText ? 80 : 56,
        label: l10n.carbs,
        value: totals.carbs,
        goal: goals.carbs,
        color: AppTheme.carbs,
      ),
      MacroRing(
        size: largeText ? 80 : 56,
        label: l10n.fat,
        value: totals.fat,
        goal: goals.fat,
        color: AppTheme.fat,
      ),
      MacroRing(
        size: largeText ? 80 : 56,
        label: l10n.fiber,
        value: totals.fiber,
        goal: goals.fiber,
        color: AppTheme.fiber,
      ),
    ];

    final macroRows = largeText
        ? LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: rings
                    .map((ring) => SizedBox(width: width, child: ring))
                    .toList(),
              );
            },
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: rings.map((ring) => Flexible(child: ring)).toList(),
          );
    final content = macroRows;
    void openDetails() => Navigator.push(
          context,
          AppTheme.slideRoute(MacroDetailsScreen(totals: totals, goals: goals)),
        );
    if (embedded) {
      return Semantics(
        button: true,
        label: l10n.macronutrients,
        child: InkWell(onTap: openDetails, child: content),
      );
    }
    return GlassCard(
      onTap: openDetails,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: content,
    );
  }
}
