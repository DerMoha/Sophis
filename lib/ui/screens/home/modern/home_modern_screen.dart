import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../../../../models/app_settings.dart';
import '../../../../../models/custom_meal_type.dart';
import '../../../../../services/nutrition_provider.dart';
import '../../../../../services/settings_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/animations.dart';
import '../../../components/organic_components.dart';
import '../../../components/streak_card.dart';
import '../../../components/supplements_today_card.dart';
import '../../goals_setup_screen.dart';
import '../../settings_screen.dart';
import '../shared/home_refresh.dart';
import '../shared/home_dashboard_vm.dart';
import '../shared/home_actions.dart';
import 'widgets/widgets.dart';

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
      refreshBurnedCalories(context);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
          return _buildDashboard(context, l10n, theme, nutrition);
        },
      ),
    );
  }

  HomeDashboardVM _buildVM(
    BuildContext context,
    NutritionProvider nutrition,
  ) {
    final waterGoalMl = context.select<SettingsProvider, double>(
      (s) => s.waterGoalMl,
    );
    final unitSystem = context.select<SettingsProvider, UnitSystem>(
      (s) => s.unitSystem,
    );
    final mealTypes = context.select<SettingsProvider, List<CustomMealType>>(
      (s) => s.mealTypes,
    );
    final showMealMacros = context.select<SettingsProvider, bool>(
      (s) => s.showMealMacros,
    );
    final healthSyncEnabled = context.select<SettingsProvider, bool>(
      (s) => s.healthSyncEnabled,
    );
    final visibleDashboardCards =
        context.select<SettingsProvider, List<DashboardCard>>(
      (s) => s.visibleDashboardCards,
    );
    final quickActionSize = context.select<SettingsProvider, QuickActionSize>(
      (s) => s.quickActionSize,
    );

    return buildHomeDashboardVM(
      nutrition,
      waterGoalMl: waterGoalMl,
      unitSystem: unitSystem,
      mealTypes: mealTypes,
      showMealMacros: showMealMacros,
      healthSyncEnabled: healthSyncEnabled,
      visibleDashboardCards: visibleDashboardCards,
      quickActionSize: quickActionSize,
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    NutritionProvider nutrition,
  ) {
    final vm = _buildVM(context, nutrition);
    final showSupplements = context.select<SettingsProvider, bool>(
      (s) => s.showSupplements,
    );
    final actions = buildHomeActions(
      context,
      l10n,
      theme,
      vm.visibleDashboardCards,
    );
    final children = <Widget>[];
    var fadeIndex = 0;

    void addFade(Widget child) {
      children.add(FadeInSlide(index: fadeIndex, child: child));
      fadeIndex += 1;
    }

    void addSpace(double height) {
      children.add(SizedBox(height: height));
    }

    addFade(
      CalorieHeroCard(
        consumed: vm.totals.calories,
        baseGoal: vm.goals.calories.toDouble(),
        effectiveGoal: vm.effectiveGoal,
        remaining: vm.remaining,
        progress: vm.calorieProgress,
        burnedCalories: vm.burnedCalories,
      ),
    );
    addSpace(12);
    children.add(const StreakCard());
    addFade(MacrosCard(totals: vm.totals, goals: vm.goals));
    addSpace(16);
    addFade(
      WaterCard(
        waterTotal: vm.waterTotal,
        waterGoal: vm.waterGoal,
        unitSystem: vm.unitSystem,
      ),
    );
    if (showSupplements) {
      addSpace(16);
      addFade(const SupplementsTodayCard());
      addSpace(24);
    } else {
      addSpace(24);
    }
    addFade(
      SectionHeader(
        title: l10n.today,
        icon: Icons.restaurant_outlined,
      ),
    );

    for (var i = 0; i < vm.mealTypes.length; i++) {
      final mealType = vm.mealTypes[i];
      addFade(
        MealSection(
          mealType: mealType.id,
          title: mealType.name,
          icon: mealType.icon,
          color: mealType.color,
          showMacros: vm.showMealMacros,
        ),
      );
      if (i < vm.mealTypes.length - 1) {
        addSpace(12);
      }
    }

    addSpace(24);
    if (actions.isNotEmpty) {
      addFade(
        QuickActionsSection(
          actions: actions,
          size: vm.quickActionSize,
        ),
      );
    }

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
                      child: const Icon(
                        Icons.restaurant_menu_rounded,
                        size: 32,
                        color: Colors.white,
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
