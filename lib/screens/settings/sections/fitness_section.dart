import 'package:flutter/material.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/settings_provider.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/components/settings/settings_tiles.dart';

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
      ],
    );
  }
}
