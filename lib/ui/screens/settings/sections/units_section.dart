import 'package:flutter/material.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/app_settings.dart';
import 'package:sophis/services/settings_provider.dart';
import 'package:sophis/ui/components/settings/settings_tiles.dart';

class UnitsSection extends StatelessWidget {
  final SettingsProvider settings;

  const UnitsSection({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = [
      (UnitSystem.metric, l10n.metric, l10n.metricSubtitle),
      (UnitSystem.imperial, l10n.imperial, l10n.imperialSubtitle),
    ];

    return Column(
      children: options.map((option) {
        final isSelected = settings.unitSystem == option.$1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SelectableOptionTile(
            title: option.$2,
            subtitle: option.$3,
            icon: option.$1 == UnitSystem.metric
                ? Icons.balance_outlined
                : Icons.scale_outlined,
            isSelected: isSelected,
            onTap: () => settings.setUnitSystem(option.$1),
          ),
        );
      }).toList(),
    );
  }
}
