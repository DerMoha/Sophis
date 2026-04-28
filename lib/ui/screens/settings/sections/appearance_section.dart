import 'package:flutter/material.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/app_settings.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/components/settings/settings_tiles.dart';

class AppearanceSection extends StatelessWidget {
  final SettingsProvider settings;

  const AppearanceSection({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingRow(
          title: l10n.theme,
          child: SegmentedControl<ThemeMode>(
            value: settings.themeMode,
            options: const [
              (ThemeMode.system, Icons.brightness_auto),
              (ThemeMode.light, Icons.light_mode_outlined),
              (ThemeMode.dark, Icons.dark_mode_outlined),
            ],
            onChanged: settings.setThemeMode,
          ),
        ),
        const SizedBox(height: AppTheme.spaceLG2),
        SettingRow(
          title: l10n.quickActionsSize,
          child: SegmentedControl<QuickActionSize>(
            value: settings.quickActionSize,
            options: const [
              (QuickActionSize.small, Icons.view_column_rounded),
              (QuickActionSize.large, Icons.grid_view_rounded),
            ],
            onChanged: settings.setQuickActionSize,
          ),
        ),
        const SizedBox(height: AppTheme.spaceLG2),
        Text(l10n.accentColor, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppTheme.spaceSM2),
        _AccentColorPicker(settings: settings),
      ],
    );
  }
}

class _AccentColorPicker extends StatelessWidget {
  final SettingsProvider settings;

  const _AccentColorPicker({required this.settings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: AccentColors.presets.map((color) {
        final isSelected = color.toARGB32() == settings.accentColorValue;
        return GestureDetector(
          onTap: () => settings.setAccentColor(color.toARGB32()),
          child: AnimatedContainer(
            duration: AppTheme.animFast,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: theme.colorScheme.onSurface, width: 3)
                  : Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(Icons.check, color: _contrastColor(color), size: 20)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Color _contrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
