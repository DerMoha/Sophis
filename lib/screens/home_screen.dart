import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/app_settings.dart';
import '../models/food_entry.dart';
import '../models/shareable_meal.dart';
import '../services/nutrition_provider.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../utils/unit_converter.dart';
import '../widgets/organic_components.dart';
import 'goals_setup_screen.dart';
import 'settings_screen.dart';
import 'add_food_screen.dart';
import 'food_search_screen.dart';
import 'barcode_scanner_screen.dart';
import 'weight_tracker_screen.dart';
import 'recipes_screen.dart';
import 'ai_food_camera_screen.dart';
import 'activity_graph_screen.dart';
import 'meal_planner_screen.dart';
import 'share_meal_screen.dart';
import 'food_diary_screen.dart';
import 'meal_detail_screen.dart';
import '../widgets/water_details_sheet.dart';
import '../widgets/workout_bottom_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late ScrollController _scrollController;
  // Use ValueNotifier to avoid full rebuilds on scroll - only widgets that
  // listen via ValueListenableBuilder will rebuild
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        // Update ValueNotifier instead of calling setState
        _scrollOffset.value = _scrollController.offset;
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshBurnedCalories();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  Future<void> _refreshBurnedCalories() async {
    final settings = context.read<SettingsProvider>();
    final nutrition = context.read<NutritionProvider>();
    await nutrition.refreshBurnedCalories(enabled: settings.healthSyncEnabled);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: Consumer<NutritionProvider>(
        builder: (context, nutrition, _) {
          if (nutrition.goals == null) {
            return _buildWelcomeView(context, l10n, theme);
          }
          return _buildDashboard(context, l10n, theme, nutrition);
        },
      ),
    );
  }

  Widget _buildWelcomeView(
      BuildContext context, AppLocalizations l10n, ThemeData theme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            FadeInSlide(
              index: 0,
              child: Text(
                l10n.appTitle,
                style: theme.textTheme.displaySmall,
              ),
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
                            theme.colorScheme.primary.withOpacity(0.7),
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
                    Text(
                      l10n.welcomeTitle,
                      style: theme.textTheme.headlineMedium,
                    ),
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

  Widget _buildDashboard(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    NutritionProvider nutrition,
  ) {
    final totals = nutrition.getTodayTotals();
    final goals = nutrition.goals!;
    final remaining = nutrition.getRemainingCalories();
    final burnedCalories = nutrition.burnedCalories;
    final settings = context.watch<SettingsProvider>();
    final waterTotal = nutrition.getTodayWaterTotal();
    final waterGoal = settings.waterGoalMl;

    // Effective goal = base goal + burned calories (exercise earns extra calories)
    final effectiveGoal = goals.calories + burnedCalories;
    final calorieProgress =
        (totals['calories']! / effectiveGoal).clamp(0.0, 1.0);

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Animated App Bar - Uses ValueListenableBuilder to avoid full rebuilds
        ValueListenableBuilder<double>(
          valueListenable: _scrollOffset,
          builder: (context, scrollOffset, child) {
            return SliverAppBar(
              expandedHeight: 100,
              floating: true,
              pinned: true,
              backgroundColor: theme.scaffoldBackgroundColor.withOpacity(
                (scrollOffset / 100).clamp(0.0, 1.0),
              ),
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
                title: AnimatedOpacity(
                  opacity: scrollOffset > 50 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    l10n.appTitle,
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
            background: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
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
                          _getGreeting(l10n),
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
                      color: theme.colorScheme.outline.withOpacity(0.1),
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
                  _refreshBurnedCalories();
                },
              ),
            ),
          ],
        );
          },
        ),

        // Main Content
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Hero Calorie Card
              FadeInSlide(
                index: 0,
                child: _buildCalorieHeroCard(
                  context,
                  l10n,
                  theme,
                  totals,
                  goals,
                  effectiveGoal,
                  remaining,
                  calorieProgress,
                  burnedCalories,
                  settings.healthSyncEnabled,
                ),
              ),
              const SizedBox(height: 20),

              // Macro Rings Row
              FadeInSlide(
                index: 1,
                child: _buildMacroRingsCard(context, l10n, theme, totals, goals),
              ),
              const SizedBox(height: 20),

              // Water Tracker
              FadeInSlide(
                index: 2,
                child: _buildWaterCard(context, l10n, theme, waterTotal, waterGoal, settings.unitSystem),
              ),
              const SizedBox(height: 24),

              // Quick Actions - Dynamic Grid
              FadeInSlide(
                index: 3,
                child: _buildQuickActionsGrid(context, l10n, theme, settings),
              ),
              const SizedBox(height: 32),

              // Meals Section
              FadeInSlide(
                index: 4,
                child: SectionHeader(
                  title: l10n.today,
                  icon: Icons.restaurant_outlined,
                ),
              ),

              _buildMealSection(context, l10n, 'breakfast', l10n.breakfast,
                  Icons.wb_twilight_rounded, 5),
              const SizedBox(height: 12),
              _buildMealSection(context, l10n, 'lunch', l10n.lunch,
                  Icons.wb_sunny_rounded, 6),
              const SizedBox(height: 12),
              _buildMealSection(context, l10n, 'dinner', l10n.dinner,
                  Icons.nights_stay_rounded, 7),
              const SizedBox(height: 12),
              _buildMealSection(context, l10n, 'snack', l10n.snacks,
                  Icons.cookie_outlined, 8),
            ]),
          ),
        ),
      ],
    );
  }

  String _getGreeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.today;
    if (hour < 17) return l10n.today;
    return l10n.today;
  }

  Widget _buildCalorieHeroCard(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    Map<String, double> totals,
    goals,
    double effectiveGoal,
    double remaining,
    double progress,
    double burnedCalories,
    bool healthSyncEnabled,
  ) {
    final isOver = remaining < 0;
    final statusColor = isOver ? AppTheme.error : AppTheme.success;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Radial Progress - fixed size
          RadialProgress(
            value: progress,
            size: 130,
            strokeWidth: 12,
            color: theme.colorScheme.primary,
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withOpacity(0.6),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedNumber(
                  value: totals['calories']!,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Boosted goal display with visual indicator
                _BoostedGoalDisplay(
                  baseGoal: goals.calories.toDouble(),
                  effectiveGoal: effectiveGoal,
                  burnedCalories: burnedCalories,
                ),
                Text(
                  'kcal',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Stats Column - flexible
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.calories,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                // Remaining badge
                _CompactStatRow(
                  icon: isOver
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  value: remaining.abs().toStringAsFixed(0),
                  label: isOver ? l10n.over : l10n.remaining,
                  color: statusColor,
                ),
                // Burned calories (from workouts + health sync)
                if (burnedCalories > 0) ...[
                  const SizedBox(height: 8),
                  _CompactStatRow(
                    icon: Icons.local_fire_department_rounded,
                    value: burnedCalories.toStringAsFixed(0),
                    label: l10n.burned('').trim(),
                    color: AppTheme.fire,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRingsCard(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    Map<String, double> totals,
    goals,
  ) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          MacroRing(
            label: l10n.protein,
            value: totals['protein']!,
            goal: goals.protein,
            color: AppTheme.protein,
          ),
          MacroRing(
            label: l10n.carbs,
            value: totals['carbs']!,
            goal: goals.carbs,
            color: AppTheme.carbs,
          ),
          MacroRing(
            label: l10n.fat,
            value: totals['fat']!,
            goal: goals.fat,
            color: AppTheme.fat,
          ),
        ],
      ),
    );
  }

  Widget _buildWaterCard(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    double waterTotal,
    double waterGoal,
    UnitSystem unitSystem,
  ) {
    final progress = (waterTotal / waterGoal).clamp(0.0, 1.0);
    final totalDisplay = UnitConverter.formatWater(waterTotal, unitSystem);
    final goalDisplay = UnitConverter.formatWater(waterGoal, unitSystem);

    return GlassCard(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const WaterDetailsSheet(),
        );
      },
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.water.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.water_drop_rounded,
                      color: AppTheme.water,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(l10n.water, style: theme.textTheme.titleMedium),
                ],
              ),
              Text(
                '$totalDisplay / $goalDisplay',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppTheme.water,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FluidProgressBar(
            value: progress,
            color: AppTheme.water,
            height: 10,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: WaterDropButton(
                  label: '+250ml',
                  onPressed: () =>
                      context.read<NutritionProvider>().addWater(250),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WaterDropButton(
                  label: '+500ml',
                  onPressed: () =>
                      context.read<NutritionProvider>().addWater(500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    SettingsProvider settings,
  ) {
    final visibleCards = settings.visibleDashboardCards;

    if (visibleCards.isEmpty) {
      return const SizedBox.shrink();
    }

    // Build rows of 2 cards each
    final rows = <Widget>[];
    for (var i = 0; i < visibleCards.length; i += 2) {
      final firstCard = _buildQuickActionCardForId(
        context, l10n, theme, visibleCards[i].id,
      );
      final secondCard = i + 1 < visibleCards.length
          ? _buildQuickActionCardForId(
              context, l10n, theme, visibleCards[i + 1].id,
            )
          : null;

      rows.add(Row(
        children: [
          Expanded(child: firstCard),
          const SizedBox(width: 12),
          if (secondCard != null)
            Expanded(child: secondCard)
          else
            const Expanded(child: SizedBox()),
        ],
      ));

      if (i + 2 < visibleCards.length) {
        rows.add(const SizedBox(height: 12));
      }
    }

    return Column(children: rows);
  }

  Widget _buildQuickActionCardForId(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    String id,
  ) {
    switch (id) {
      case DashboardCardIds.foodDiary:
        return QuickActionCard(
          icon: Icons.history_rounded,
          label: l10n.foodDiary,
          color: theme.colorScheme.primary,
          onTap: () => Navigator.push(
            context,
            AppTheme.slideRoute(const FoodDiaryScreen()),
          ),
        );
      case DashboardCardIds.mealPlanner:
        return QuickActionCard(
          icon: Icons.calendar_month_outlined,
          label: l10n.mealPlanner,
          onTap: () => Navigator.push(
            context,
            AppTheme.slideRoute(const MealPlannerScreen()),
          ),
        );
      case DashboardCardIds.weight:
        return QuickActionCard(
          icon: Icons.monitor_weight_outlined,
          label: l10n.weight,
          onTap: () => Navigator.push(
            context,
            AppTheme.slideRoute(const WeightTrackerScreen()),
          ),
        );
      case DashboardCardIds.recipes:
        return QuickActionCard(
          icon: Icons.menu_book_outlined,
          label: l10n.recipes,
          onTap: () => Navigator.push(
            context,
            AppTheme.slideRoute(const RecipesScreen()),
          ),
        );
      case DashboardCardIds.activity:
        return QuickActionCard(
          icon: Icons.insights_outlined,
          label: l10n.activity,
          onTap: () => Navigator.push(
            context,
            AppTheme.slideRoute(const ActivityGraphScreen()),
          ),
        );
      case DashboardCardIds.workout:
        return QuickActionCard(
          icon: Icons.local_fire_department_rounded,
          label: l10n.workout,
          color: AppTheme.fire,
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const WorkoutBottomSheet(),
            );
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMealSection(
    BuildContext context,
    AppLocalizations l10n,
    String mealType,
    String title,
    IconData icon,
    int animationIndex,
  ) {
    final entries =
        context.watch<NutritionProvider>().getEntriesByMeal(mealType);
    final total = entries.fold(0.0, (sum, e) => sum + e.calories);
    final theme = Theme.of(context);

    return FadeInSlide(
      index: animationIndex,
      child: MealCard(
        title: title,
        icon: icon,
        calories: total,
        onHeaderTap: () => Navigator.push(
          context,
          AppTheme.slideRoute(MealDetailScreen(
            mealType: mealType,
            mealTitle: title,
            mealIcon: icon,
          )),
        ),
        addMenu: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Share button (only visible when there are entries)
            if (entries.isNotEmpty)
              IconButton(
                icon: Icon(
                  Icons.share_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: () => _shareMeal(context, l10n, entries, title),
                tooltip: l10n.share,
              ),
            // Add menu
            PopupMenuButton<String>(
              icon: Icon(
                Icons.add_circle_outline,
                color: theme.colorScheme.primary,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              onSelected: (value) => _handleMealAction(context, value, mealType),
              itemBuilder: (_) => [
                _buildPopupItem(Icons.edit_outlined, l10n.manualEntry, 'manual'),
                _buildPopupItem(Icons.search_outlined, l10n.searchFood, 'search'),
                _buildPopupItem(
                    Icons.qr_code_scanner_outlined, l10n.scanBarcode, 'barcode'),
                _buildPopupItem(
                    Icons.auto_awesome_outlined, l10n.aiRecognition, 'ai'),
              ],
            ),
          ],
        ),
        entries: entries.isEmpty
            ? [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Text(
                    l10n.noEntries,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ]
            : entries
                .map((entry) => FoodEntryTile(
                      key: ValueKey(entry.id), // Key for efficient list updates
                      name: entry.name,
                      calories: entry.calories,
                      protein: entry.protein,
                      carbs: entry.carbs,
                      fat: entry.fat,
                      onLongPress: () => _showEntryOptions(context, l10n, entry),
                    ))
                .toList(),
      ),
    );
  }

  void _shareMeal(
    BuildContext context,
    AppLocalizations l10n,
    List<FoodEntry> entries,
    String title,
  ) {
    final meal = ShareableMeal.fromFoodEntries(entries, title: title);
    Navigator.push(
      context,
      AppTheme.slideRoute(ShareMealScreen(meal: meal)),
    );
  }

  void _shareSingleItem(BuildContext context, FoodEntry entry) {
    final meal = ShareableMeal.fromFoodEntries([entry]);
    Navigator.push(
      context,
      AppTheme.slideRoute(ShareMealScreen(meal: meal)),
    );
  }

  PopupMenuItem<String> _buildPopupItem(
      IconData icon, String label, String value) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  void _handleMealAction(BuildContext context, String action, String mealType) {
    Widget screen;
    switch (action) {
      case 'manual':
        screen = AddFoodScreen(meal: mealType);
        break;
      case 'search':
        screen = FoodSearchScreen(meal: mealType);
        break;
      case 'barcode':
        screen = BarcodeScannerScreen(meal: mealType);
        break;
      case 'ai':
        screen = AIFoodCameraScreen(meal: mealType);
        break;
      default:
        return;
    }
    Navigator.push(context, AppTheme.slideRoute(screen));
  }

  void _showEntryOptions(BuildContext context, AppLocalizations l10n, FoodEntry entry) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.share_outlined, color: theme.colorScheme.primary),
              title: Text(l10n.share),
              onTap: () {
                Navigator.pop(ctx);
                _shareSingleItem(context, entry);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              title: Text(l10n.delete, style: TextStyle(color: theme.colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirmation(context, l10n, entry);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, AppLocalizations l10n, FoodEntry entry) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteConfirmation(entry.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              context.read<NutritionProvider>().removeFoodEntry(entry.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

/// Boosted goal display - shows when exercise has expanded the calorie budget
class _BoostedGoalDisplay extends StatefulWidget {
  final double baseGoal;
  final double effectiveGoal;
  final double burnedCalories;

  const _BoostedGoalDisplay({
    required this.baseGoal,
    required this.effectiveGoal,
    required this.burnedCalories,
  });

  @override
  State<_BoostedGoalDisplay> createState() => _BoostedGoalDisplayState();
}

class _BoostedGoalDisplayState extends State<_BoostedGoalDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  bool get isBoosted => widget.burnedCalories > 0;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    if (isBoosted) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_BoostedGoalDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (isBoosted && !_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
    } else if (!isBoosted && _glowController.isAnimating) {
      _glowController.stop();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Normal display when not boosted
    if (!isBoosted) {
      return Text(
        '/ ${widget.baseGoal.toStringAsFixed(0)}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    // Boosted display with fire accent and glow
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Boosted goal with glow effect
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.fire.withOpacity(0.3 * _glowAnimation.value),
                    blurRadius: 8 * _glowAnimation.value,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Struck-through base goal
                  Text(
                    widget.baseGoal.toStringAsFixed(0),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                      decoration: TextDecoration.lineThrough,
                      decorationColor: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Arrow indicator
                  Icon(
                    Icons.arrow_forward,
                    size: 8,
                    color: AppTheme.fire.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  // New boosted goal
                  Text(
                    '/ ${widget.effectiveGoal.toStringAsFixed(0)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.fire,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            // Bonus badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.fire.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.fire.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 10,
                    color: AppTheme.fire,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '+${widget.burnedCalories.toStringAsFixed(0)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.fire,
                      fontWeight: FontWeight.w600,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Compact stat row that doesn't overflow
class _CompactStatRow extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _CompactStatRow({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: RichText(
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: ' $label',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
