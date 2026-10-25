import 'package:flutter/material.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/app_settings.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/ui/components/common/app_surface.dart';
import 'package:sophis/ui/screens/dashboard_settings_screen.dart';
import 'package:sophis/ui/theme/app_theme.dart';

class AppearanceSection extends StatelessWidget {
  final SettingsProvider settings;

  const AppearanceSection({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themes = [
      (ThemeMode.system, l10n.systemDefault, Icons.brightness_auto_outlined),
      (ThemeMode.light, l10n.light, Icons.light_mode_outlined),
      (ThemeMode.dark, l10n.dark, Icons.dark_mode_outlined),
    ];
    final sizes = [
      (
        QuickActionSize.small,
        l10n.quickActionsCompact,
        Icons.view_column_rounded
      ),
      (QuickActionSize.large, l10n.quickActionsLarge, Icons.grid_view_rounded),
    ];

    return Column(
      children: [
        AppSection(
          title: l10n.theme,
          children: [
            for (final (index, option) in themes.indexed)
              AppOptionRow(
                title: option.$2,
                icon: option.$3,
                selected: settings.themeMode == option.$1,
                showDivider: index < themes.length - 1,
                onTap: () => settings.setThemeMode(option.$1),
              ),
          ],
        ),
        const SizedBox(height: 20),
        AppSection(
          title: l10n.accentColor,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _AccentColorPicker(settings: settings),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AppSection(
          title: l10n.dashboard,
          children: [
            AppNavigationRow(
              title: l10n.customizeDashboard,
              subtitle: l10n.customizeDashboardSubtitle,
              icon: Icons.dashboard_customize_outlined,
              showDivider: false,
              onTap: () => Navigator.push(
                context,
                AppTheme.slideRoute(const DashboardSettingsScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AppSection(
          title: l10n.quickActionsSize,
          children: [
            for (final (index, option) in sizes.indexed)
              AppOptionRow(
                title: option.$2,
                icon: option.$3,
                selected: settings.quickActionSize == option.$1,
                showDivider: index < sizes.length - 1,
                onTap: () => settings.setQuickActionSize(option.$1),
              ),
          ],
        ),
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
        return Semantics(
          button: true,
          selected: isSelected,
          child: GestureDetector(
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
