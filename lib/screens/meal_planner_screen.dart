import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/meal_plan.dart';
import '../services/nutrition_provider.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../widgets/organic_components.dart';
import 'add_planned_meal_sheet.dart';

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
    _dayPageController = PageController(initialPage: _daysRange + _selectedDayOffset);
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
        (MediaQuery.of(context).size.width / 2) + 40;

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

  String _getDayName(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  String _getMonthName(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[date.month - 1];
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

                  return FadeInSlide(
                    index: 1,
                    child: Consumer<NutritionProvider>(
                      builder: (context, nutrition, _) {
                        return _buildDayContent(
                          context, theme, isDark, l10n, nutrition, date,
                        );
                      },
                    ),
                  );
                },
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
                    isToday
                        ? '${l10n.today}, ${selectedDate.day} ${_getMonthName(selectedDate)}'
                        : '${_getDayName(selectedDate)}, ${selectedDate.day} ${_getMonthName(selectedDate)}',
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
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDaySelector(ThemeData theme, bool isDark, AppLocalizations l10n) {
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
            selector: (_, provider) => provider.getPlannedMealsForDate(date).isNotEmpty,
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
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.06),
                  width: isToday && !isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
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
                    _getDayName(date),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? Colors.white.withOpacity(0.8)
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
                          ? Colors.white
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
                              ? Colors.white
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
    bool isDark,
    AppLocalizations l10n,
    NutritionProvider nutrition,
    DateTime date,
  ) {
    final totals = nutrition.getPlannedTotalsForDate(date);
    final goals = nutrition.goals;
    final meals = nutrition.getPlannedMealsForDate(date);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        // Nutrition summary (only if there are meals)
        if (meals.isNotEmpty)
          _buildNutritionSummary(theme, isDark, l10n, totals, goals),

        if (meals.isNotEmpty)
          const SizedBox(height: 24),

        // Meal sections
        _buildMealSection(
          context, theme, isDark, l10n, nutrition,
          date, 'breakfast', l10n.breakfast, Icons.wb_sunny_outlined,
        ),
        const SizedBox(height: 12),
        _buildMealSection(
          context, theme, isDark, l10n, nutrition,
          date, 'lunch', l10n.lunch, Icons.restaurant_outlined,
        ),
        const SizedBox(height: 12),
        _buildMealSection(
          context, theme, isDark, l10n, nutrition,
          date, 'dinner', l10n.dinner, Icons.nightlight_outlined,
        ),
        const SizedBox(height: 12),
        _buildMealSection(
          context, theme, isDark, l10n, nutrition,
          date, 'snack', l10n.snacks, Icons.cookie_outlined,
        ),

        // Helpful tip when empty
        if (meals.isEmpty) ...[
          const SizedBox(height: 32),
          _buildEmptyDayHint(theme, l10n),
        ],
      ],
    );
  }

  Widget _buildEmptyDayHint(ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restaurant_menu_outlined,
              size: 28,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noMealsPlanned,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.tapToAddFirstMeal,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionSummary(
    ThemeData theme,
    bool isDark,
    AppLocalizations l10n,
    Map<String, double> totals,
    goals,
  ) {
    final calorieGoal = goals?.calories ?? 2000;
    final calorieProgress = (totals['calories']! / calorieGoal).clamp(0.0, 1.5);
    final isOverGoal = totals['calories']! > calorieGoal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.1),
            theme.colorScheme.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Calorie ring
              SizedBox(
                width: 80,
                height: 80,
                child: RadialProgress(
                  value: calorieProgress,
                  size: 80,
                  strokeWidth: 8,
                  color: isOverGoal ? AppTheme.error : theme.colorScheme.primary,
                  showGlow: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        totals['calories']!.toStringAsFixed(0),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isOverGoal ? AppTheme.error : null,
                        ),
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
              ),
              const SizedBox(width: 20),
              // Macros
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.plannedNutrition,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildMiniMacro(
                          theme, l10n.protein,
                          totals['protein']!, AppTheme.protein,
                        ),
                        const SizedBox(width: 16),
                        _buildMiniMacro(
                          theme, l10n.carbs,
                          totals['carbs']!, AppTheme.carbs,
                        ),
                        const SizedBox(width: 16),
                        _buildMiniMacro(
                          theme, l10n.fat,
                          totals['fat']!, AppTheme.fat,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isOverGoal) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: AppTheme.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${(totals['calories']! - calorieGoal).toStringAsFixed(0)} ${l10n.over}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniMacro(ThemeData theme, String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${value.toStringAsFixed(0)}g',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMealSection(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    AppLocalizations l10n,
    NutritionProvider nutrition,
    DateTime date,
    String mealType,
    String title,
    IconData icon,
  ) {
    final meals = nutrition.getPlannedMealsByType(date, mealType);
    final totalCal = meals.fold(0.0, (sum, m) => sum + m.calories);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => _showAddMealSheet(context, mealType: mealType),
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        if (totalCal > 0)
                          Text(
                            '${totalCal.toStringAsFixed(0)} kcal',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else
                          Text(
                            l10n.tapToAdd,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.add_circle_outline,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          // Meals
          if (meals.isNotEmpty) ...[
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.04),
            ),
            ...meals.map((meal) => _buildPlannedMealTile(
              context, theme, isDark, l10n, nutrition, meal,
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildPlannedMealTile(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    AppLocalizations l10n,
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
      child: InkWell(
        onTap: () => _showMealOptions(context, meal, nutrition),
        onLongPress: () => _showCopyDialog(context, meal),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _MacroChip(
                          label: 'P',
                          value: meal.protein,
                          color: AppTheme.protein,
                        ),
                        const SizedBox(width: 8),
                        _MacroChip(
                          label: 'C',
                          value: meal.carbs,
                          color: AppTheme.carbs,
                        ),
                        const SizedBox(width: 8),
                        _MacroChip(
                          label: 'F',
                          value: meal.fat,
                          color: AppTheme.fat,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '${meal.calories.toStringAsFixed(0)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' kcal',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
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
                leading: Icon(Icons.check_circle_outline,
                    color: theme.colorScheme.primary),
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
                leading: Icon(Icons.copy_outlined,
                    color: theme.colorScheme.primary),
                title: Text(l10n.copyToAnotherDay),
                onTap: () {
                  Navigator.pop(context);
                  _showCopyDialog(context, meal);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.error),
                title: Text(l10n.delete,
                    style: const TextStyle(color: AppTheme.error)),
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
      initialDate: _getDateForOffset(_selectedDayOffset).add(const Duration(days: 1)),
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

class _MacroChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${value.toStringAsFixed(0)}g',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
