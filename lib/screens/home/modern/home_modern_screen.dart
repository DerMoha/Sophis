import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/nutrition_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/animations.dart';
import '../../../widgets/organic_components.dart';
import '../../../widgets/streak_card.dart';
import '../../../widgets/supplements_today_card.dart';
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
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() => _scrollOffset.value = _scrollController.offset);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshBurnedCalories(context);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollOffset.dispose();
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

  Widget _buildDashboard(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    NutritionProvider nutrition,
  ) {
    final vm = buildHomeDashboardVM(context, nutrition);
    final actions = buildHomeActions(
      context,
      l10n,
      theme,
      vm.visibleDashboardCards,
    );

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildAppBar(l10n, theme),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              FadeInSlide(
                index: 0,
                child: CalorieHeroCard(
                  consumed: vm.totals['calories']!,
                  baseGoal: vm.goals.calories.toDouble(),
                  effectiveGoal: vm.effectiveGoal,
                  remaining: vm.remaining,
                  progress: vm.calorieProgress,
                  burnedCalories: vm.burnedCalories,
                ),
              ),
              const SizedBox(height: 12),
              const StreakCard(),
              FadeInSlide(
                index: 1,
                child: MacrosCard(totals: vm.totals, goals: vm.goals),
              ),
              const SizedBox(height: 16),
              FadeInSlide(
                index: 2,
                child: WaterCard(
                  waterTotal: vm.waterTotal,
                  waterGoal: vm.waterGoal,
                  unitSystem: vm.unitSystem,
                ),
              ),
              const SizedBox(height: 16),
              const FadeInSlide(index: 3, child: SupplementsTodayCard()),
              const SizedBox(height: 24),
              FadeInSlide(
                index: 4,
                child: SectionHeader(
                  title: l10n.today,
                  icon: Icons.restaurant_outlined,
                ),
              ),
              ...vm.mealTypes.asMap().entries.expand((entry) {
                final index = entry.key;
                final mealType = entry.value;
                return [
                  FadeInSlide(
                    index: 5 + index,
                    child: MealSection(
                      mealType: mealType.id,
                      title: mealType.name,
                      icon: mealType.icon,
                      color: mealType.color,
                      showMacros: vm.showMealMacros,
                    ),
                  ),
                  if (index < vm.mealTypes.length - 1)
                    const SizedBox(height: 12),
                ];
              }),
              const SizedBox(height: 24),
              if (actions.isNotEmpty)
                FadeInSlide(
                  index: 8,
                  child: QuickActionsSection(
                    actions: actions,
                    size: vm.quickActionSize,
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(AppLocalizations l10n, ThemeData theme) {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffset,
      builder: (context, scrollOffset, _) {
        return SliverAppBar(
          expandedHeight: 100,
          floating: true,
          pinned: true,
          backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha:
            (scrollOffset / 100).clamp(0.0, 1.0),
          ),
          elevation: 0,
          centerTitle: false,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
            expandedTitleScale: 1.0,
            title: AnimatedOpacity(
              opacity: scrollOffset > 50 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                l10n.appTitle,
                style: theme.textTheme.headlineMedium,
              ),
            ),
            background: SafeArea(
              child: AnimatedOpacity(
                opacity: scrollOffset > 50 ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.appTitle, style: theme.textTheme.headlineMedium),
                          const SizedBox(height: 4),
                          Text(
                            l10n.today,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  child: const Icon(Icons.settings_outlined, size: 20),
                ),
                tooltip: l10n.settings,
                onPressed: () async {
                  await Navigator.push(
                    context,
                    AppTheme.slideRoute(const SettingsScreen()),
                  );
                  if (!mounted) return;
                  refreshBurnedCalories(context);
                },
              ),
            ),
          ],
        );
      },
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
      child: Padding(
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
            const Spacer(),
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
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.restaurant_menu_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(l10n.welcomeTitle, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 12),
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
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
