import 'package:flutter/material.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/ui/components/common/app_surface.dart';
import 'package:sophis/ui/screens/meal_types_screen.dart';
import 'package:sophis/ui/theme/app_theme.dart';

class MealsSection extends StatelessWidget {
  final SettingsProvider settings;

  const MealsSection({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppSection(
      title: l10n.settingsMeals,
      children: [
        AppNavigationRow(
          title: l10n.customizeMealTypes,
          subtitle: l10n.customizeMealTypesSubtitle,
          icon: Icons.restaurant_menu_outlined,
          onTap: () => Navigator.push(
            context,
            AppTheme.slideRoute(const MealTypesScreen()),
          ),
        ),
        AppSwitchRow(
          title: l10n.showMealMacros,
          subtitle: l10n.showMealMacrosSubtitle,
          icon: Icons.pie_chart_outline,
          value: settings.showMealMacros,
          onChanged: settings.setShowMealMacros,
          showDivider: false,
        ),
      ],
    );
  }
}
