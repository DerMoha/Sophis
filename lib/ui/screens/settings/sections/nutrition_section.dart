import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/services/settings_provider.dart';
import 'package:sophis/services/supplements_provider.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/components/settings/settings_tiles.dart';
import 'package:sophis/ui/components/settings/water_sizes_dialog.dart';
import 'package:sophis/ui/screens/goals_setup_screen.dart';
import 'package:sophis/ui/screens/meal_macros_settings_screen.dart';
import 'package:sophis/ui/screens/supplements_screen.dart';

class NutritionSection extends StatelessWidget {
  final SettingsProvider settings;

  const NutritionSection({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        NavigationTile(
          title: l10n.calorieGoals,
          subtitle: l10n.calorieGoalsSubtitle,
          icon: Icons.local_fire_department_outlined,
          onTap: () {
            Navigator.push(
              context,
              AppTheme.slideRoute(const GoalsSetupScreen()),
            );
          },
        ),
        const SizedBox(height: AppTheme.spaceSM2),
        NavigationTile(
          title: l10n.waterSizes,
          subtitle: l10n.waterSizesSubtitle,
          icon: Icons.water_drop_outlined,
          onTap: () => _showWaterSizesDialog(context, settings, l10n),
        ),
        const SizedBox(height: AppTheme.spaceSM2),
        NavigationTile(
          title: l10n.showMealMacros,
          subtitle: l10n.showMealMacrosSubtitle,
          icon: Icons.pie_chart_outline,
          onTap: () => Navigator.push(
            context,
            AppTheme.slideRoute(const MealMacrosSettingsScreen()),
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM2),
        SwitchTile(
          title: l10n.trackSupplements,
          subtitle: l10n.trackSupplementsSubtitle,
          icon: Icons.medication_outlined,
          value: settings.showSupplements,
          onChanged: (value) {
            settings.setShowSupplements(value);
            context
                .read<SupplementsProvider>()
                .updateAllNotifications(enable: value);
          },
        ),
        if (settings.showSupplements) ...[
          const SizedBox(height: AppTheme.spaceSM2),
          NavigationTile(
            title: l10n.manageSupplements,
            subtitle: l10n.manageSupplementsSubtitle,
            icon: Icons.medication_liquid_rounded,
            onTap: () => Navigator.push(
              context,
              AppTheme.slideRoute(const SupplementsScreen()),
            ),
          ),
        ],
      ],
    );
  }

  void _showWaterSizesDialog(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) => WaterSizesDialog(
        settings: settings,
        l10n: l10n,
      ),
    );
  }
}
