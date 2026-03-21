import 'package:flutter/material.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../../../../services/settings_provider.dart';
import '../../../theme/app_theme.dart';

class LanguageSection extends StatelessWidget {
  final SettingsProvider settings;

  const LanguageSection({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => settings.setLocale(option.$1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.3)
                        : theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      option.$3,
                      size: 20,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      option.$2,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    const Spacer(),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
