import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/ui/components/common/app_surface.dart';

String healthPlatformName() => defaultTargetPlatform == TargetPlatform.iOS
    ? 'Apple Health'
    : 'Health Connect';

class FitnessSection extends StatelessWidget {
  final SettingsProvider settings;

  const FitnessSection({super.key, required this.settings});

  void _showPermissionError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.healthPermissionError),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppSection(
      title: healthPlatformName(),
      footer: l10n.burnedCaloriesDisclaimer,
      children: [
        AppSwitchRow(
          title: l10n.healthSync,
          subtitle: l10n.healthSyncSubtitle,
          icon: Icons.local_fire_department_outlined,
          value: settings.healthSyncEnabled,
          onChanged: (value) async {
            final success = await settings.setHealthSyncEnabled(value);
            if (!success && value && context.mounted) {
              _showPermissionError(context);
            }
          },
        ),
        AppSwitchRow(
          title: l10n.weightSync,
          subtitle: l10n.weightSyncSubtitle,
          icon: Icons.monitor_weight_outlined,
          value: settings.healthWeightSyncEnabled,
          onChanged: (value) async {
            final success = await settings.setHealthWeightSyncEnabled(value);
            if (!success && value && context.mounted) {
              _showPermissionError(context);
            } else if (success && value && context.mounted) {
              await context.read<NutritionProvider>().syncWeightFromHealth();
            }
          },
        ),
        AppSwitchRow(
          title: l10n.nutritionSync,
          subtitle: l10n.nutritionSyncSubtitle,
          icon: Icons.restaurant_outlined,
          value: settings.healthNutritionSyncEnabled,
          showDivider: false,
          onChanged: (value) async {
            final success = await settings.setHealthNutritionSyncEnabled(value);
            if (!success && value && context.mounted) {
              _showPermissionError(context);
            }
          },
        ),
      ],
    );
  }
}
