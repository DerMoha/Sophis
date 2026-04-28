import 'package:flutter/material.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/ui/components/settings/settings_tiles.dart';

class LanguageSection extends StatelessWidget {
  final SettingsProvider settings;

  const LanguageSection({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = [
      (null, l10n.systemDefault, Icons.phone_android_outlined),
      ('en', l10n.english, Icons.language_outlined),
      ('de', l10n.german, Icons.language_outlined),
    ];

    return Column(
      children: options.map((option) {
        final isSelected = settings.localeOverride == option.$1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SelectableOptionTile(
            title: option.$2,
            icon: option.$3,
            isSelected: isSelected,
            onTap: () => settings.setLocale(option.$1),
          ),
        );
      }).toList(),
    );
  }
}
