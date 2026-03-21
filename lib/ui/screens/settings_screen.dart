import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../components/organic_components.dart';
import 'settings/sections/sections.dart';

enum _SettingsSection {
  appearance,
  nutrition,
  language,
  units,
  dashboard,
  reminders,
  fitness,
  ai,
  data,
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
            centerTitle: false,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                l10n.settings,
                style: theme.textTheme.headlineMedium,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: Consumer<SettingsProvider>(
              builder: (context, settings, _) {
                return SliverList(
                  delegate: SliverChildListDelegate([
                    FadeInSlide(
                      index: 0,
                      child: _buildSectionCard(
                        context,
                        section: _SettingsSection.appearance,
                        title: l10n.appearance,
                        icon: Icons.palette_outlined,
                        children: [AppearanceSection(settings: settings)],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeInSlide(
                      index: 1,
                      child: _buildSectionCard(
                        context,
                        section: _SettingsSection.nutrition,
                        title: l10n.nutrition,
                        icon: Icons.restaurant_outlined,
                        children: [NutritionSection(settings: settings)],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeInSlide(
                      index: 2,
                      child: _buildSectionCard(
                        context,
                        section: _SettingsSection.language,
                        title: l10n.language,
                        icon: Icons.language_outlined,
                        children: [LanguageSection(settings: settings)],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeInSlide(
                      index: 3,
                      child: _buildSectionCard(
                        context,
                        section: _SettingsSection.units,
                        title: l10n.units,
                        icon: Icons.straighten_outlined,
                        children: [UnitsSection(settings: settings)],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeInSlide(
                      index: 4,
                      child: _buildSectionCard(
                        context,
                        section: _SettingsSection.dashboard,
                        title: l10n.quickActions,
                        icon: Icons.dashboard_customize_outlined,
                        children: const [DashboardSection()],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeInSlide(
                      index: 5,
                      child: _buildSectionCard(
                        context,
                        section: _SettingsSection.reminders,
                        title: l10n.mealReminders,
                        icon: Icons.notifications_outlined,
                        children: [RemindersSection(settings: settings)],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeInSlide(
                      index: 6,
                      child: _buildSectionCard(
                        context,
                        section: _SettingsSection.fitness,
                        title: l10n.fitnessSync,
                        icon: Icons.fitness_center_outlined,
                        children: [FitnessSection(settings: settings)],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeInSlide(
                      index: 7,
                      child: _buildSectionCard(
                        context,
                        section: _SettingsSection.ai,
                        title: l10n.aiSection,
                        icon: Icons.auto_awesome_outlined,
                        children: [AiSection(settings: settings)],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeInSlide(
                      index: 8,
                      child: _buildSectionCard(
                        context,
                        section: _SettingsSection.data,
                        title: l10n.dataSection,
                        icon: Icons.folder_outlined,
                        children: const [DataSection()],
                      ),
                    ),
                    const SizedBox(height: 32),
                    FadeInSlide(
                      index: 9,
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              'Sophis',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('v1.0.0', style: theme.textTheme.bodySmall),
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
    required List<Widget> children,
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
                        borderRadius: BorderRadius.circular(10),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
