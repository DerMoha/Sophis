import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/custom_meal_type.dart';
import 'package:sophis/models/meal_plan.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/ui/components/common/ui_primitives.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/theme/animations.dart';
import 'package:sophis/ui/components/organic_components.dart';
import 'package:sophis/ui/screens/add_planned_meal_sheet.dart';

class MealPlannerScreen extends StatefulWidget {
  const MealPlannerScreen({super.key});

  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen> {
  late PageController _dayPageController;
  late ScrollController _dayScrollController;
  late DateTime _baseDate;
  int _selectedDayOffset = 0;

  static const int _daysRange = 14; // Show 2 weeks forward/back from today

  @override
  void initState() {
    super.initState();
    _baseDate = DateTime.now();
    _selectedDayOffset = 0; // Start at today
    _dayPageController =
        PageController(initialPage: _daysRange + _selectedDayOffset);
    _dayScrollController = ScrollController();

    // Scroll to center the selected day after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDay(animated: false);
    });
  }

  @override
  void dispose() {
    _dayPageController.dispose();
    _dayScrollController.dispose();
    super.dispose();
  }

  DateTime _getDateForOffset(int offset) {
    return DateTime(_baseDate.year, _baseDate.month, _baseDate.day + offset);
  }

  void _scrollToSelectedDay({bool animated = true}) {
    if (!_dayScrollController.hasClients) return;

    // Each day card is ~72 wide + 8 margin = 80
    final targetOffset = (_daysRange + _selectedDayOffset) * 80.0 -
        (MediaQuery.of(context).size.width / 2) +
        40;

    if (animated) {
      _dayScrollController.animateTo(
        targetOffset.clamp(0, _dayScrollController.position.maxScrollExtent),
        duration: AppTheme.animNormal,
        curve: Curves.easeOutCubic,
      );
    } else {
      _dayScrollController.jumpTo(
        targetOffset.clamp(0, double.infinity),
      );
    }
  }

  String _formatDayName(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.E(locale).format(date);
  }

  String _formatSelectedDate(
    BuildContext context,
    AppLocalizations l10n,
    DateTime date,
    bool isToday,
  ) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dayMonth = DateFormat('d MMMM', locale).format(date);

    if (isToday) return '${l10n.today}, $dayMonth';

    final weekday = DateFormat.E(locale).format(date);
    return '$weekday, $dayMonth';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedDate = _getDateForOffset(_selectedDayOffset);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, theme, l10n, selectedDate),

            // Horizontal scrollable day selector
            FadeInSlide(
              index: 0,
              child: _buildDaySelector(theme, isDark, l10n),
            ),

            // Swipeable day content
            Expanded(
              child: FadeInSlide(
                index: 1,
                child: PageView.builder(
                  controller: _dayPageController,
                  onPageChanged: (page) {
                    setState(() {
                      _selectedDayOffset = page - _daysRange;
                    });
                    _scrollToSelectedDay();
                    HapticFeedback.selectionClick();
                  },
                  itemBuilder: (context, index) {
                    final dayOffset = index - _daysRange;
                    final date = _getDateForOffset(dayOffset);

                    return Consumer<NutritionProvider>(
                      builder: (context, nutrition, _) {
                        return _buildDayContent(
                          context,
                          theme,
                          l10n,
                          nutrition,
                          date,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMealSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.addMeal),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    DateTime selectedDate,
  ) {
    final isToday = _selectedDayOffset == 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surface,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.mealPlanner,
                  style: theme.textTheme.headlineMedium,
                ),
                AnimatedSwitcher(
                  duration: AppTheme.animFast,
                  child: Text(
                    _formatSelectedDate(context, l10n, selectedDate, isToday),
                    key: ValueKey(selectedDate),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Jump to today button (only show if not on today)
          if (_selectedDayOffset != 0)
            IconButton(
              icon: const Icon(Icons.today_rounded),
              onPressed: () {
                setState(() {
                  _selectedDayOffset = 0;
                });
                _dayPageController.animateToPage(
                  _daysRange,
                  duration: AppTheme.animNormal,
                  curve: Curves.easeOutCubic,
                );
                _scrollToSelectedDay();
                HapticFeedback.mediumImpact();
              },
              tooltip: l10n.today,
              style: IconButton.styleFrom(
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDaySelector(
    ThemeData theme,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);

    return SizedBox(
      height: 90,
      child: ListView.builder(
        controller: _dayScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _daysRange * 2 + 1, // Days before + today + days after
        itemBuilder: (context, index) {
          final dayOffset = index - _daysRange;
          final date = _getDateForOffset(dayOffset);
          final dateNorm = DateTime(date.year, date.month, date.day);
          final isToday = dateNorm == todayNorm;
          final isSelected = dayOffset == _selectedDayOffset;

          // Use Selector to only rebuild when THIS date's meals change
          // instead of watching the entire NutritionProvider
          return Selector<NutritionProvider, bool>(
            selector: (_, provider) => provider.hasPlannedMealsForDate(date),
            builder: (context, hasMeals, child) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDayOffset = dayOffset;
                  });
                  _dayPageController.animateToPage(
                    index,
                    duration: AppTheme.animNormal,
                    curve: Curves.easeOutCubic,
                  );
                  HapticFeedback.selectionClick();
                },
                child: AnimatedContainer(
                  duration: AppTheme.animFast,
                  width: 72,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : isToday
                              ? theme.colorScheme.primary
                              : isDark
                                  ? CachedColors.borderDark
                                  : CachedColors.borderLight,
                      width: isToday && !isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Day name
                      Text(
                        _formatDayName(context, date),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? theme.colorScheme.onPrimary.withValues(alpha: 0.8)
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Day number
                      Text(
                        '${date.day}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: isSelected
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Meal indicator
                      AnimatedContainer(
                        duration: AppTheme.animFast,
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: hasMeals
                              ? (isSelected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.primary)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDayContent(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    NutritionProvider nutrition,
    DateTime date,
  ) {
    final totals = nutrition.getPlannedTotalsForDate(date);
    final goals = nutrition.goals;
    final meals = nutrition.getPlannedMealsForDate(date);
    final mealTypes = context.select<SettingsProvider, List<CustomMealType>>(
      (settings) => settings.mealTypes,
    );

    return ListView(
      padding: AppTheme.pagePaddingTop,
      children: [
        // Nutrition summary (only if there are meals)
        if (meals.isNotEmpty)
          NutritionSummaryCard(
            title: l10n.plannedNutrition,
            proteinLabel: l10n.protein,
            carbsLabel: l10n.carbs,
            fatLabel: l10n.fat,
            overGoalLabel: l10n.over,
            totals: totals,
            goals: goals,
          ),

        if (meals.isNotEmpty) const SizedBox(height: 24),

        ...mealTypes.asMap().entries.expand((entry) {
          final index = entry.key;
          final mealType = entry.value;

          return [
            _buildMealSection(
              context,
              l10n,
              nutrition,
              date,
              mealType,
            ),
            if (index < mealTypes.length - 1)
              const SizedBox(height: AppTheme.spaceSM2),
          ];
        }),

        // Helpful tip when empty
        if (meals.isEmpty) ...[
          const SizedBox(height: 32),
          EmptyDayHint(
            icon: Icons.restaurant_menu_outlined,
            title: l10n.noMealsPlanned,
            subtitle: l10n.tapToAddFirstMeal,
          ),
        ],
      ],
    );
  }

  Widget _buildMealSection(
    BuildContext context,
    AppLocalizations l10n,
    NutritionProvider nutrition,
    DateTime date,
    CustomMealType mealType,
  ) {
    final meals = nutrition.getPlannedMealsByType(date, mealType.id);
    final totalCal = meals.fold(0.0, (sum, m) => sum + m.calories);

    return MealCard(
      title: mealType.name,
      icon: mealType.icon,
      calories: totalCal,
      color: mealType.color,
      emptyLabel: l10n.tapToAdd,
      onHeaderTap: () => _showAddMealSheet(context, mealType: mealType.id),
      onAddPressed: () => _showAddMealSheet(context, mealType: mealType.id),
      showHeaderChevron: false,
      entries: meals
          .map(
            (meal) => _buildPlannedMealTile(
              context,
              nutrition,
              meal,
            ),
          )
          .toList(),
    );
  }

  Widget _buildPlannedMealTile(
    BuildContext context,
    NutritionProvider nutrition,
    PlannedMeal meal,
  ) {
    return Dismissible(
      key: Key(meal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppTheme.error,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => nutrition.removePlannedMeal(meal.id),
      child: FoodEntryTile(
        name: meal.name,
        calories: meal.calories,
        protein: meal.protein,
        carbs: meal.carbs,
        fat: meal.fat,
        onTap: () => _showMealOptions(context, meal, nutrition),
        onLongPress: () => _showCopyDialog(context, meal),
      ),
    );
  }

  void _showAddMealSheet(BuildContext context, {String? mealType}) {
    final selectedDate = _getDateForOffset(_selectedDayOffset);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPlannedMealSheet(
        date: selectedDate,
        initialMealType: mealType,
      ),
    );
  }

  void _showMealOptions(
    BuildContext context,
    PlannedMeal meal,
    NutritionProvider nutrition,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.check_circle_outline,
                  color: theme.colorScheme.primary,
                ),
                title: Text(l10n.logAsEaten),
                subtitle: Text(l10n.logAsEatenSubtitle),
                onTap: () {
                  nutrition.logPlannedMeal(meal);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.addedSnack(meal.name))),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.copy_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: Text(l10n.copyToAnotherDay),
                onTap: () {
                  Navigator.pop(context);
                  _showCopyDialog(context, meal);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppTheme.error),
                title: Text(
                  l10n.delete,
                  style: const TextStyle(color: AppTheme.error),
                ),
                onTap: () {
                  nutrition.removePlannedMeal(meal.id);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCopyDialog(BuildContext context, PlannedMeal meal) async {
    final nutrition = context.read<NutritionProvider>();
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final selectedDate = await showDatePicker(
      context: context,
      initialDate:
          _getDateForOffset(_selectedDayOffset).add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: l10n.selectDate,
    );

    if (selectedDate != null && mounted) {
      nutrition.copyPlannedMealToDate(meal, selectedDate);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.mealCopied)),
      );
    }
  }
}
