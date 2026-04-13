import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../../../../services/nutrition_provider.dart';
import '../../../../../services/settings_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../components/settings/settings_tiles.dart';

class FitnessSection extends StatelessWidget {
  final SettingsProvider settings;

  const FitnessSection({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      children: [
        SwitchTile(
          title: l10n.healthSync,
          subtitle: l10n.healthSyncSubtitle,
          icon: Icons.favorite_outline,
          value: settings.healthSyncEnabled,
          onChanged: (value) async {
            final success = await settings.setHealthSyncEnabled(value);
            if (!success && value && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.healthPermissionError)),
              );
            }
          },
        ),
        const SizedBox(height: 8),
        Text(
          l10n.burnedCaloriesDisclaimer,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM2),
        SwitchTile(
          title: l10n.weightSync,
          subtitle: l10n.weightSyncSubtitle,
          icon: Icons.monitor_weight_outlined,
          value: settings.healthWeightSyncEnabled,
          onChanged: (value) async {
            final success = await settings.setHealthWeightSyncEnabled(value);
            if (!success && value && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.healthPermissionError)),
              );
            } else if (success && value && context.mounted) {
              await context.read<NutritionProvider>().syncWeightFromHealth();
            }
          },
        ),
        const SizedBox(height: AppTheme.spaceSM2),
        SwitchTile(
          title: l10n.nutritionSync,
          subtitle: l10n.nutritionSyncSubtitle,
          icon: Icons.restaurant_outlined,
          value: settings.healthNutritionSyncEnabled,
          onChanged: (value) async {
            final success = await settings.setHealthNutritionSyncEnabled(value);
            if (!success && value && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.healthPermissionError)),
              );
            }
          },
        ),
      ],
    );
  }
}
