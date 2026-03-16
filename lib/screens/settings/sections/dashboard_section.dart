import 'package:flutter/material.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/settings_provider.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/components/settings/settings_tiles.dart';
import '../../dashboard_settings_screen.dart';
import '../../meal_types_screen.dart';

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
        const SizedBox(height: 12),
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
