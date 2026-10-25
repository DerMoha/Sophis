import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sophis/config/launch_config.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/app_settings.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/ui/components/common/app_surface.dart';
import 'package:sophis/ui/components/settings/water_sizes_dialog.dart';
import 'package:sophis/ui/screens/goals_setup_screen.dart';
import 'package:sophis/ui/screens/social/people_screen.dart';
import 'package:sophis/ui/screens/settings/sections/sections.dart';
import 'package:sophis/ui/theme/app_theme.dart';

typedef _SectionBuilder = Widget Function(SettingsProvider settings);

class SettingsScreen extends StatelessWidget {
  final bool _showAiSection;

  const SettingsScreen({super.key}) : _showAiSection = false;

  const SettingsScreen.ai({super.key}) : _showAiSection = true;

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, AppTheme.slideRoute(screen));
  }

  void _openSection(
    BuildContext context, {
    required String title,
    required _SectionBuilder builder,
  }) {
    _push(context, _SettingsDetailScreen(title: title, builder: builder));
  }

  Future<void> _openUrl(BuildContext context, String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || !await launchUrl(uri)) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.externalLinkNotConfigured)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_showAiSection) {
      return _SettingsDetailScreen(
        title: l10n.aiSection,
        builder: (settings) => AiSection(settings: settings),
      );
    }

    final settings = context.watch<SettingsProvider>();
    final calorieGoal = context.select<NutritionProvider, double?>(
      (nutrition) => nutrition.goals?.calories,
    );
    String onOff(bool value) => value ? l10n.settingOn : l10n.settingOff;
    final themeLabel = switch (settings.themeMode) {
      ThemeMode.system => l10n.systemDefault,
      ThemeMode.light => l10n.light,
      ThemeMode.dark => l10n.dark,
    };
    final languageLabel = switch (settings.localeOverride) {
      'en' => l10n.english,
      'de' => l10n.german,
      _ => l10n.systemDefault,
    };
    final unitLabel =
        settings.unitSystem == UnitSystem.metric ? l10n.metric : l10n.imperial;
    final activeHealthSyncs = [
      settings.healthSyncEnabled,
      settings.healthWeightSyncEnabled,
      settings.healthNutritionSyncEnabled,
    ].where((enabled) => enabled).length;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: AppTheme.pagePadding,
        children: [
          AppSection(
            title: l10n.settingsNutritionAndGoals,
            children: [
              AppNavigationRow(
                title: l10n.calorieGoals,
                subtitle: calorieGoal == null
                    ? l10n.notSet
                    : '${calorieGoal.round()} kcal',
                icon: Icons.local_fire_department_outlined,
                onTap: () => _push(context, const GoalsSetupScreen()),
              ),
              AppNavigationRow(
                title: l10n.settingsMeals,
                subtitle: l10n.settingsMealsSummary(settings.mealTypes.length),
                icon: Icons.restaurant_menu_outlined,
                onTap: () => _openSection(
                  context,
                  title: l10n.settingsMeals,
                  builder: (settings) => MealsSection(settings: settings),
                ),
              ),
              AppNavigationRow(
                title: l10n.waterSizes,
                subtitle: '${settings.waterSizes.join(' · ')} ml',
                icon: Icons.water_drop_outlined,
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      WaterSizesDialog(settings: settings, l10n: l10n),
                ),
              ),
              AppNavigationRow(
                title: l10n.supplements,
                subtitle: onOff(settings.showSupplements),
                icon: Icons.medication_outlined,
                showDivider: false,
                onTap: () => _openSection(
                  context,
                  title: l10n.supplements,
                  builder: (settings) => SupplementsSection(settings: settings),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppSection(
            title: l10n.settingsApp,
            children: [
              AppNavigationRow(
                title: l10n.appearance,
                subtitle: themeLabel,
                icon: Icons.palette_outlined,
                onTap: () => _openSection(
                  context,
                  title: l10n.appearance,
                  builder: (settings) => AppearanceSection(settings: settings),
                ),
              ),
              AppNavigationRow(
                title: l10n.languageAndUnits,
                subtitle: '$languageLabel · $unitLabel',
                icon: Icons.language_outlined,
                onTap: () => _openSection(
                  context,
                  title: l10n.languageAndUnits,
                  builder: (settings) =>
                      LanguageAndUnitsSection(settings: settings),
                ),
              ),
              AppNavigationRow(
                title: l10n.mealReminders,
                subtitle: onOff(settings.remindersEnabled),
                icon: Icons.notifications_outlined,
                showDivider: false,
                onTap: () => _openSection(
                  context,
                  title: l10n.mealReminders,
                  builder: (settings) => RemindersSection(settings: settings),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppSection(
            title: l10n.connections,
            children: [
              AppNavigationRow(
                title: healthPlatformName(),
                subtitle: activeHealthSyncs == 0
                    ? l10n.settingOff
                    : l10n.healthSyncActive(activeHealthSyncs),
                icon: Icons.favorite_outline,
                onTap: () => _openSection(
                  context,
                  title: healthPlatformName(),
                  builder: (settings) => FitnessSection(settings: settings),
                ),
              ),
              AppNavigationRow(
                title: l10n.aiSection,
                subtitle:
                    settings.hasGeminiApiKey ? l10n.aiKeySet : l10n.notSetUp,
                icon: Icons.auto_awesome_outlined,
                onTap: () => _openSection(
                  context,
                  title: l10n.aiSection,
                  builder: (settings) => AiSection(settings: settings),
                ),
              ),
              AppNavigationRow(
                title: l10n.offAccountTitle,
                subtitle: settings.hasOffCredentials
                    ? l10n.offSignedIn
                    : l10n.offAnonymous,
                icon: Icons.public_outlined,
                onTap: () => _openSection(
                  context,
                  title: l10n.offAccountTitle,
                  builder: (settings) =>
                      OpenFoodFactsSection(settings: settings),
                ),
              ),
              AppNavigationRow(
                title: l10n.partnerSharingLabel,
                subtitle: l10n.partnerSharingSubtitle,
                icon: Icons.people_outline,
                showDivider: false,
                onTap: () => _push(context, const PeopleScreen()),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppSection(
            title: l10n.privacyAndData,
            children: [
              AppNavigationRow(
                title: l10n.privacy,
                subtitle: l10n.progressPhotoLock,
                icon: Icons.lock_outline,
                onTap: () => _openSection(
                  context,
                  title: l10n.privacy,
                  builder: (settings) => PrivacySection(settings: settings),
                ),
              ),
              AppNavigationRow(
                title: l10n.dataSection,
                subtitle: l10n.dataSectionSubtitle,
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
          const SizedBox(height: 20),
          AppSection(
            title: l10n.aboutSophis,
            footer: l10n.medicalDisclaimer,
            children: [
              AppNavigationRow(
                title: l10n.support,
                icon: Icons.support_agent_outlined,
                external: true,
                onTap: () => _openUrl(context, LaunchConfig.supportUrl),
              ),
              AppNavigationRow(
                title: l10n.privacyPolicy,
                icon: Icons.policy_outlined,
                external: true,
                onTap: () => _openUrl(context, LaunchConfig.privacyPolicyUrl),
              ),
              AppNavigationRow(
                title: l10n.terms,
                icon: Icons.description_outlined,
                external: true,
                showDivider: false,
                onTap: () => _openUrl(context, LaunchConfig.termsUrl),
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
