import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/services/nutrition_provider.dart';
import 'package:sophis/ui/screens/food_diary/food_diary_vm.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/theme/animations.dart';
import 'package:sophis/ui/components/organic_components.dart';

/// Screen for browsing food diary entries across different dates
class FoodDiaryScreen extends StatefulWidget {
  const FoodDiaryScreen({super.key});

  @override
  State<FoodDiaryScreen> createState() => _FoodDiaryScreenState();
}

class _FoodDiaryScreenState extends State<FoodDiaryScreen> {
  late PageController _pageController;
  late DateTime _baseDate;
  int _selectedDayOffset = 0;

  static const int _daysRange = 30; // Show 30 days back

  @override
  void initState() {
    super.initState();
    _baseDate = DateTime.now();
    _selectedDayOffset = 0; // Start at today
    _pageController =
        PageController(initialPage: _daysRange + _selectedDayOffset);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _getDateForOffset(int offset) {
    final today = DateTime(_baseDate.year, _baseDate.month, _baseDate.day);
    return today.add(Duration(days: offset));
  }

  String _getDayName(DateTime date, AppLocalizations l10n, String locale) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateNorm = DateTime(date.year, date.month, date.day);

    if (dateNorm == today) {
      return l10n.today;
    }
    if (dateNorm == today.subtract(const Duration(days: 1))) {
      return l10n.yesterday;
    }

    // Use intl for localized day names (e.g., 'Mon' in EN, 'Mo' in DE)
    return DateFormat.E(locale).format(date);
  }

  String _getFormattedDate(DateTime date, String locale) {
    // Use intl for localized date format (e.g., '10 January 2026')
    return DateFormat.yMMMMd(locale).format(date);
  }

  void _goToPreviousDay() {
    _pageController.previousPage(
      duration: AppTheme.animNormal,
      curve: Curves.easeOutCubic,
    );
    HapticFeedback.selectionClick();
  }

  void _goToNextDay() {
    // Don't go beyond today
    if (_selectedDayOffset >= 0) return;
    _pageController.nextPage(
      duration: AppTheme.animNormal,
      curve: Curves.easeOutCubic,
    );
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final selectedDate = _getDateForOffset(_selectedDayOffset);
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header with date navigation
            _buildHeader(context, theme, l10n, selectedDate, locale),

            // Swipeable day content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _selectedDayOffset = page - _daysRange;
                  });
                  HapticFeedback.selectionClick();
                },
                itemCount: _daysRange + 1, // Days back + today
                itemBuilder: (context, index) {
                  final dayOffset = index - _daysRange;
                  final date = _getDateForOffset(dayOffset);

                  return FadeInSlide(
                    index: 0,
                    child: Consumer<NutritionProvider>(
                      builder: (context, nutrition, _) {
                        return _buildDayContent(
                          context,
                          theme,
                          l10n,
                          nutrition,
                          date,
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
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    DateTime selectedDate,
    String locale,
  ) {
    final canGoForward = _selectedDayOffset < 0;

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
          // Previous day button
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _goToPreviousDay,
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surface,
            ),
          ),
          // Date display
          Expanded(
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: AppTheme.animFast,
                  child: Text(
                    _getDayName(selectedDate, l10n, locale),
                    key: ValueKey('name_$selectedDate'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: AppTheme.animFast,
                  child: Text(
                    _getFormattedDate(selectedDate, locale),
                    key: ValueKey('date_$selectedDate'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Next day button
          IconButton(
            icon: Icon(
              Icons.chevron_right_rounded,
              color: canGoForward
                  ? null
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            onPressed: canGoForward ? _goToNextDay : null,
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surface,
            ),
          ),
          const SizedBox(width: 12),
          // Jump to today button (only show if not on today)
          if (_selectedDayOffset != 0)
            IconButton(
              icon: const Icon(Icons.today_rounded),
              onPressed: () {
                _pageController.animateToPage(
                  _daysRange,
                  duration: AppTheme.animNormal,
                  curve: Curves.easeOutCubic,
                );
                HapticFeedback.mediumImpact();
              },
              tooltip: l10n.today,
              style: IconButton.styleFrom(
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                foregroundColor: theme.colorScheme.primary,
              ),
            )
          else
            const SizedBox(width: 48), // Placeholder for layout consistency
        ],
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
    final vm = buildFoodDiaryVM(context, nutrition, date);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // Nutrition summary (only if there are entries)
        if (!vm.isEmpty)
          NutritionSummaryCard(
            title: l10n.summary,
            proteinLabel: l10n.protein,
            carbsLabel: l10n.carbs,
            fatLabel: l10n.fat,
            totals: vm.totals,
            goals: vm.goals,
          ),

        if (!vm.isEmpty) const SizedBox(height: 24),

        // Meal sections - dynamic from settings
        ...vm.mealTypes.asMap().entries.expand((entry) {
          final index = entry.key;
          final mealType = entry.value;
          final mealEntries =
              vm.entriesByMeal[mealType.id] ?? const <FoodEntry>[];

          return [
            _buildMealSection(
              theme,
              l10n,
              mealEntries,
              mealType.name,
              mealType.icon,
              mealType.color,
            ),
            if (index < vm.mealTypes.length - 1)
              const SizedBox(height: AppTheme.spaceSM2),
          ];
        }),

        // Helpful hint when empty
        if (vm.isEmpty) ...[
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
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restaurant_menu_outlined,
              size: 28,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noEntriesForDay,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealSection(
    ThemeData theme,
    AppLocalizations l10n,
    List<FoodEntry> mealEntries,
    String title,
    IconData icon, [
    Color? color,
  ]) {
    final totalCal =
        mealEntries.fold(0.0, (double sum, FoodEntry e) => sum + e.calories);
    final mealColor = color ?? theme.colorScheme.primary;

    return MealCard(
      title: title,
      icon: icon,
      calories: totalCal,
      color: mealColor,
      emptyLabel: l10n.noEntries,
      entries: mealEntries
          .map(
            (entry) => KeyedSubtree(
              key: ValueKey(entry.id),
              child: _buildEntryTile(entry),
            ),
          )
          .toList(),
    );
  }

  Widget _buildEntryTile(FoodEntry entry) {
    return FoodEntryTile(
      name: entry.name,
      calories: entry.calories,
      protein: entry.protein,
      carbs: entry.carbs,
      fat: entry.fat,
    );
  }
}
