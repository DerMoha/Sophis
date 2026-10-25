import 'package:flutter/material.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/app_settings.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/ui/components/common/app_surface.dart';

class LanguageAndUnitsSection extends StatelessWidget {
  final SettingsProvider settings;

  const LanguageAndUnitsSection({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languages = [
      (null, l10n.systemDefault, Icons.phone_android_outlined),
      ('en', l10n.english, Icons.language_outlined),
      ('de', l10n.german, Icons.language_outlined),
    ];
    final units = [
      (
        UnitSystem.metric,
        l10n.metric,
        l10n.metricSubtitle,
        Icons.balance_outlined
      ),
      (
        UnitSystem.imperial,
        l10n.imperial,
        l10n.imperialSubtitle,
        Icons.scale_outlined
      ),
    ];

    return Column(
      children: [
        AppSection(
          title: l10n.language,
          children: [
            for (final (index, option) in languages.indexed)
              AppOptionRow(
                title: option.$2,
                icon: option.$3,
                selected: settings.localeOverride == option.$1,
                showDivider: index < languages.length - 1,
                onTap: () => settings.setLocale(option.$1),
              ),
          ],
        ),
        const SizedBox(height: 20),
        AppSection(
          title: l10n.units,
          children: [
            for (final (index, option) in units.indexed)
              AppOptionRow(
                title: option.$2,
                subtitle: option.$3,
                icon: option.$4,
                selected: settings.unitSystem == option.$1,
                showDivider: index < units.length - 1,
                onTap: () => settings.setUnitSystem(option.$1),
              ),
          ],
        ),
      ],
    );
  }
}
