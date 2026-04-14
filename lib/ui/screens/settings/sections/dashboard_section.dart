import 'package:flutter/material.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/components/settings/settings_tiles.dart';
import 'package:sophis/ui/screens/dashboard_settings_screen.dart';
import 'package:sophis/ui/screens/meal_types_screen.dart';

class DashboardSection extends StatelessWidget {
  const DashboardSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        NavigationTile(
          title: l10n.customizeDashboard,
          subtitle: l10n.customizeDashboardSubtitle,
          icon: Icons.grid_view_outlined,
          onTap: () => Navigator.push(
            context,
            AppTheme.slideRoute(const DashboardSettingsScreen()),
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM2),
        NavigationTile(
          title: l10n.customizeMealTypes,
          subtitle: l10n.customizeMealTypesSubtitle,
          icon: Icons.restaurant_menu_outlined,
          onTap: () => Navigator.push(
            context,
            AppTheme.slideRoute(const MealTypesScreen()),
          ),
        ),
      ],
    );
  }
}
