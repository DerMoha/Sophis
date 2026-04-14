import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/services/settings_provider.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/theme/animations.dart';
import 'package:sophis/ui/components/organic_components.dart';
import 'package:sophis/ui/screens/settings/sections/sections.dart';

enum _SettingsSection {
  appearance,
  nutrition,
  language,
  units,
  dashboard,
  reminders,
  fitness,
  ai,
  openfoodfacts,
  data,
}

class _SettingsSectionConfig {
  final _SettingsSection section;
  final String title;
  final IconData icon;
  final Widget child;

  const _SettingsSectionConfig({
    required this.section,
    required this.title,
    required this.icon,
    required this.child,
  });
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Map<_SettingsSection, bool> _expandedSections = {
    for (final section in _SettingsSection.values) section: false,
  };
  late final Future<String> _versionLabelFuture;

  @override
  void initState() {
    super.initState();
    _versionLabelFuture = _loadVersionLabel();
  }

  Future<String> _loadVersionLabel() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (packageInfo.buildNumber.isEmpty) {
      return 'v${packageInfo.version}';
    }
    return 'v${packageInfo.version}+${packageInfo.buildNumber}';
  }

  bool _isSectionExpanded(_SettingsSection section) =>
      _expandedSections[section] ?? false;

  void _toggleSection(_SettingsSection section) {
    setState(() {
      _expandedSections[section] = !_isSectionExpanded(section);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            floating: true,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            centerTitle: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.zero,
              title: Text(
                l10n.settings,
                style: theme.textTheme.headlineMedium,
              ),
            ),
          ),
          SliverPadding(
            padding: AppTheme.pagePadding,
            sliver: Consumer<SettingsProvider>(
              builder: (context, settings, _) {
                final sectionConfigs = <_SettingsSectionConfig>[
                  _SettingsSectionConfig(
                    section: _SettingsSection.appearance,
                    title: l10n.appearance,
                    icon: Icons.palette_outlined,
                    child: AppearanceSection(settings: settings),
                  ),
                  _SettingsSectionConfig(
                    section: _SettingsSection.nutrition,
                    title: l10n.nutrition,
                    icon: Icons.restaurant_outlined,
                    child: NutritionSection(settings: settings),
                  ),
                  _SettingsSectionConfig(
                    section: _SettingsSection.language,
                    title: l10n.language,
                    icon: Icons.language_outlined,
                    child: LanguageSection(settings: settings),
                  ),
                  _SettingsSectionConfig(
                    section: _SettingsSection.units,
                    title: l10n.units,
                    icon: Icons.straighten_outlined,
                    child: UnitsSection(settings: settings),
                  ),
                  _SettingsSectionConfig(
                    section: _SettingsSection.dashboard,
                    title: l10n.quickActions,
                    icon: Icons.dashboard_customize_outlined,
                    child: const DashboardSection(),
                  ),
                  _SettingsSectionConfig(
                    section: _SettingsSection.reminders,
                    title: l10n.mealReminders,
                    icon: Icons.notifications_outlined,
                    child: RemindersSection(settings: settings),
                  ),
                  _SettingsSectionConfig(
                    section: _SettingsSection.fitness,
                    title: l10n.fitnessSync,
                    icon: Icons.fitness_center_outlined,
                    child: FitnessSection(settings: settings),
                  ),
                  _SettingsSectionConfig(
                    section: _SettingsSection.ai,
                    title: l10n.aiSection,
                    icon: Icons.auto_awesome_outlined,
                    child: AiSection(settings: settings),
                  ),
                  _SettingsSectionConfig(
                    section: _SettingsSection.openfoodfacts,
                    title: l10n.offAccountTitle,
                    icon: Icons.public_outlined,
                    child: OpenFoodFactsSection(settings: settings),
                  ),
                  _SettingsSectionConfig(
                    section: _SettingsSection.data,
                    title: l10n.dataSection,
                    icon: Icons.folder_outlined,
                    child: const DataSection(),
                  ),
                ];

                return SliverList(
                  delegate: SliverChildListDelegate([
                    ...sectionConfigs.asMap().entries.expand((entry) {
                      final index = entry.key;
                      final config = entry.value;

                      return [
                        FadeInSlide(
                          index: index,
                          child: _buildSectionCard(
                            context,
                            section: config.section,
                            title: config.title,
                            icon: config.icon,
                            child: config.child,
                          ),
                        ),
                        if (index < sectionConfigs.length - 1)
                          const SizedBox(height: 16),
                      ];
                    }),
                    const SizedBox(height: 32),
                    FadeInSlide(
                      index: sectionConfigs.length,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLG),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.08,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSM,
                                ),
                              ),
                              child: Icon(
                                Icons.spa_rounded,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Sophis',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            FutureBuilder<String>(
                              future: _versionLabelFuture,
                              builder: (context, snapshot) {
                                final versionLabel = snapshot.data ??
                                    'v${const String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0')}';
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusFull,
                                    ),
                                  ),
                                  child: Text(
                                    versionLabel,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required _SettingsSection section,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final isExpanded = _isSectionExpanded(section);

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleSection(section),
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      ),
                      child: Icon(
                        icon,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleMedium),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: AppTheme.animFast,
                      child: Icon(
                        Icons.expand_more,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: AppTheme.animFast,
            curve: Curves.easeOutCubic,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: child,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
