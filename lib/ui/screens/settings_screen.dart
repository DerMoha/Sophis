import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/ui/components/common/app_surface.dart';
import 'package:sophis/ui/screens/meal_types_screen.dart';
import 'package:sophis/ui/screens/settings/sections/sections.dart';
import 'package:sophis/ui/theme/app_theme.dart';

typedef _SectionBuilder = Widget Function(SettingsProvider settings);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _openSection(
    BuildContext context, {
    required String title,
    required _SectionBuilder builder,
  }) {
    Navigator.push(
      context,
      AppTheme.slideRoute(
        _SettingsDetailScreen(title: title, builder: builder),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: AppTheme.pagePadding,
        children: [
          AppSection(
            title: l10n.general,
            children: [
              AppNavigationRow(
                title: l10n.appearance,
                icon: Icons.palette_outlined,
                onTap: () => _openSection(
                  context,
                  title: l10n.appearance,
                  builder: (settings) => AppearanceSection(settings: settings),
                ),
              ),
              AppNavigationRow(
                title: l10n.nutrition,
                icon: Icons.restaurant_outlined,
                onTap: () => _openSection(
                  context,
                  title: l10n.nutrition,
                  builder: (settings) => NutritionSection(settings: settings),
                ),
              ),
              AppNavigationRow(
                title: l10n.customizeMealTypes,
                icon: Icons.restaurant_menu_outlined,
                onTap: () => Navigator.push(
                  context,
                  AppTheme.slideRoute(const MealTypesScreen()),
                ),
              ),
              AppNavigationRow(
                title: l10n.language,
                icon: Icons.language_outlined,
                onTap: () => _openSection(
                  context,
                  title: l10n.language,
                  builder: (settings) => LanguageSection(settings: settings),
                ),
              ),
              AppNavigationRow(
                title: l10n.units,
                icon: Icons.straighten_outlined,
                showDivider: false,
                onTap: () => _openSection(
                  context,
                  title: l10n.units,
                  builder: (settings) => UnitsSection(settings: settings),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AppSection(
            title: l10n.connections,
            children: [
              AppNavigationRow(
                title: l10n.mealReminders,
                icon: Icons.notifications_outlined,
                onTap: () => _openSection(
                  context,
                  title: l10n.mealReminders,
                  builder: (settings) => RemindersSection(settings: settings),
                ),
              ),
              AppNavigationRow(
                title: l10n.fitnessSync,
                icon: Icons.fitness_center_outlined,
                onTap: () => _openSection(
                  context,
                  title: l10n.fitnessSync,
                  builder: (settings) => FitnessSection(settings: settings),
                ),
              ),
              AppNavigationRow(
                title: l10n.aiSection,
                icon: Icons.auto_awesome_outlined,
                onTap: () => _openSection(
                  context,
                  title: l10n.aiSection,
                  builder: (settings) => AiSection(settings: settings),
                ),
              ),
              AppNavigationRow(
                title: l10n.offAccountTitle,
                icon: Icons.public_outlined,
                showDivider: false,
                onTap: () => _openSection(
                  context,
                  title: l10n.offAccountTitle,
                  builder: (settings) =>
                      OpenFoodFactsSection(settings: settings),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AppSection(
            title: l10n.privacyAndData,
            children: [
              AppNavigationRow(
                title: l10n.privacy,
                icon: Icons.lock_outline,
                onTap: () => _openSection(
                  context,
                  title: l10n.privacy,
                  builder: (settings) => PrivacySection(settings: settings),
                ),
              ),
              AppNavigationRow(
                title: l10n.dataSection,
                icon: Icons.folder_outlined,
                showDivider: false,
                onTap: () => _openSection(
                  context,
                  title: l10n.dataSection,
                  builder: (_) => const DataSection(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const _VersionFooter(),
        ],
      ),
    );
  }
}

class _SettingsDetailScreen extends StatelessWidget {
  final String title;
  final _SectionBuilder builder;

  const _SettingsDetailScreen({required this.title, required this.builder});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: AppTheme.pagePadding,
        child: Consumer<SettingsProvider>(
          builder: (context, settings, _) => builder(settings),
        ),
      ),
    );
  }
}

class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  Future<String> _version() async {
    final info = await PackageInfo.fromPlatform();
    return info.buildNumber.isEmpty
        ? 'Sophis v${info.version}'
        : 'Sophis v${info.version}+${info.buildNumber}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _version(),
      builder: (context, snapshot) => Text(
        snapshot.data ?? 'Sophis',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
