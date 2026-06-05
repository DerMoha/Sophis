import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/theme/animations.dart';
import 'package:sophis/ui/screens/goals_setup_screen.dart';
import 'package:sophis/ui/screens/settings_screen.dart';
import 'package:sophis/ui/screens/home/shared/dashboard_slot.dart';
import 'package:sophis/ui/screens/home/shared/home_dashboard_vm.dart';
import 'package:sophis/ui/components/organic_components.dart';

class HomeScreenModern extends StatefulWidget {
  const HomeScreenModern({super.key});

  @override
  State<HomeScreenModern> createState() => _HomeScreenModernState();
}

class _HomeScreenModernState extends State<HomeScreenModern> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshBurnedCalories(context);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshBurnedCalories(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final nutrition = context.read<NutritionProvider>();
    await nutrition.refreshBurnedCalories(
      enabled: settings.healthSyncEnabled,
    );
    if (settings.healthWeightSyncEnabled) {
      await nutrition.syncWeightFromHealth();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: Consumer<NutritionProvider>(
        builder: (context, nutrition, _) {
          if (nutrition.goals == null) {
            return _WelcomeView(l10n: l10n, theme: theme);
          }
          return _buildDashboard(context, l10n, theme);
        },
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final vm = readHomeDashboardVM(context);
    final slots = buildDashboardSlots(context, vm);
    final children = dashboardSlotsToWidgets(context, slots);

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.appTitle,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.today,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                        border: Border.all(
                          color:
                              theme.colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      ),
                      child: const Icon(Icons.settings_outlined, size: 20),
                    ),
                    tooltip: l10n.settings,
                    onPressed: () async {
                      final settings = context.read<SettingsProvider>();
                      final nutrition = context.read<NutritionProvider>();
                      await Navigator.push(
                        context,
                        AppTheme.slideRoute(const SettingsScreen()),
                      );
                      if (!mounted) return;
                      await nutrition.refreshBurnedCalories(
                        enabled: settings.healthSyncEnabled,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: AppTheme.pagePaddingTop,
          sliver: SliverList(
            delegate: SliverChildListDelegate(children),
          ),
        ),
      ],
    );
  }
}

class _WelcomeView extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;

  const _WelcomeView({required this.l10n, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            FadeInSlide(
              index: 0,
              child: Text(l10n.appTitle, style: theme.textTheme.displaySmall),
            ),
            const SizedBox(height: 8),
            FadeInSlide(
              index: 1,
              child: Text(
                l10n.today,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 32),
            FadeInSlide(
              index: 2,
              child: OrganicCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                      ),
                      child: Icon(
                        Icons.restaurant_menu_rounded,
                        size: 32,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.welcomeTitle,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppTheme.spaceSM2),
                    Text(
                      l10n.welcomeSubtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          AppTheme.slideRoute(const GoalsSetupScreen()),
                        ),
                        child: Text(l10n.setGoals),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
