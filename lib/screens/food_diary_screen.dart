import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/food_entry.dart';
import '../services/nutrition_provider.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../widgets/organic_components.dart';

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
    _pageController = PageController(initialPage: _daysRange + _selectedDayOffset);
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
    
    if (dateNorm == today) return l10n.today;
    if (dateNorm == today.subtract(const Duration(days: 1))) return l10n.yesterday;
    
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
    final isDark = theme.brightness == Brightness.dark;
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
              color: canGoForward ? null : theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
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
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
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
    bool isDark,
    AppLocalizations l10n,
    NutritionProvider nutrition,
    DateTime date,
  ) {
    final entries = nutrition.getEntriesForDate(date);
    final goals = nutrition.goals;
    final totals = nutrition.getTotalsForDate(date);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // Nutrition summary (only if there are entries)
        if (entries.isNotEmpty)
          _buildNutritionSummary(theme, isDark, l10n, totals, goals),

        if (entries.isNotEmpty)
          const SizedBox(height: 24),

        // Meal sections - dynamic from settings
        ...context.read<SettingsProvider>().mealTypes.asMap().entries.expand((entry) {
          final index = entry.key;
          final mealType = entry.value;
          return [
            _buildMealSection(
              context, theme, isDark, l10n, entries,
              mealType.id, mealType.name, mealType.icon, mealType.color,
            ),
            if (index < context.read<SettingsProvider>().mealTypes.length - 1)
              const SizedBox(height: 12),
          ];
        }),

        // Helpful hint when empty
        if (entries.isEmpty) ...[
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
            l10n.noEntriesForDay,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
      child: Row(
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
                  l10n.summary,
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
    List<FoodEntry> entries,
    String mealType,
    String title,
    IconData icon, [
    Color? color,
  ]) {
    final mealEntries = entries.where((e) => e.meal == mealType).toList();
    final totalCal = mealEntries.fold(0.0, (double sum, FoodEntry e) => sum + e.calories);
    final mealColor = color ?? theme.colorScheme.primary;

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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: mealColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: mealColor,
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
                            color: mealColor,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        Text(
                          l10n.noEntries,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Entries
          if (mealEntries.isNotEmpty) ...[
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.04),
            ),
            ...mealEntries.map((entry) => _buildEntryTile(theme, entry)),
          ],
        ],
      ),
    );
  }

  Widget _buildEntryTile(ThemeData theme, FoodEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
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
                      value: entry.protein,
                      color: AppTheme.protein,
                    ),
                    const SizedBox(width: 8),
                    _MacroChip(
                      label: 'C',
                      value: entry.carbs,
                      color: AppTheme.carbs,
                    ),
                    const SizedBox(width: 8),
                    _MacroChip(
                      label: 'F',
                      value: entry.fat,
                      color: AppTheme.fat,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${entry.calories.toStringAsFixed(0)}',
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
    );
  }
}

/// Small macro label chip
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            value.toStringAsFixed(0),
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
