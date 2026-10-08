import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/ui/components/common/ui_primitives.dart';
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
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final dateTitle = Column(
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
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: largeText
          ? Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.surface,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: _goToPreviousDay,
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.surface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.chevron_right_rounded,
                        color: canGoForward
                            ? null
                            : theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.3),
                      ),
                      onPressed: canGoForward ? _goToNextDay : null,
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.surface,
                      ),
                    ),
                    const SizedBox(width: 12),
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
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                dateTitle,
              ],
            )
          : Row(
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
                Expanded(child: dateTitle),
                // Next day button
                IconButton(
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: canGoForward
                        ? null
                        : theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.3),
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
                  const SizedBox(
                    width: 48,
                  ), // Placeholder for layout consistency
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
        if (_isToday(date)) ...[
          _buildReuseCard(
            context,
            theme,
            l10n,
            nutrition,
            vm.entries,
          ),
          const SizedBox(height: AppTheme.spaceLG),
        ],
        // Nutrition summary (only if there are entries)
        if (!vm.isEmpty)
          NutritionSummaryCard(
            title: l10n.summary,
            proteinLabel: l10n.protein,
            carbsLabel: l10n.carbs,
            fatLabel: l10n.fat,
            fiberLabel: l10n.fiber,
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
          EmptyDayHint(
            icon: Icons.restaurant_menu_outlined,
            title: l10n.noEntriesForDay,
          ),
        ],
      ],
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

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _buildReuseCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    NutritionProvider nutrition,
    List<FoodEntry> todayEntries,
  ) {
    final currentMealEntries = todayEntries.isEmpty
        ? const <FoodEntry>[]
        : nutrition.getLastLoggedMealEntries();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.reuseMeal,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final entries = await nutrition.repeatLastMeal(
                    timestamp: DateTime.now(),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        entries.isEmpty
                            ? l10n.noMealsToRepeat
                            : l10n.lastMealRepeated,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.replay_outlined, size: 18),
                label: Text(l10n.repeatLastMeal),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final entries = await nutrition.copyYesterdayLoggedMeals(
                    targetDate: DateTime.now(),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        entries.isEmpty
                            ? l10n.noMealsYesterday
                            : l10n.mealsCopied,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.history_outlined, size: 18),
                label: Text(l10n.copyYesterdayMeals),
              ),
              if (currentMealEntries.isNotEmpty)
                FilledButton.tonalIcon(
                  onPressed: () => _showSaveTemplateDialog(
                    context,
                    l10n,
                    nutrition,
                    currentMealEntries,
                  ),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: Text(l10n.saveMealTemplate),
                ),
            ],
          ),
          if (nutrition.mealTemplates.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.savedTemplates,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: nutrition.mealTemplates
                  .map(
                    (template) => ActionChip(
                      avatar: const Icon(Icons.bookmark_outline, size: 16),
                      label: Text(template.name),
                      onPressed: () async {
                        await nutrition.logMealTemplate(template);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.mealTemplateLogged)),
                        );
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showSaveTemplateDialog(
    BuildContext context,
    AppLocalizations l10n,
    NutritionProvider nutrition,
    List<FoodEntry> entries,
  ) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.saveMealTemplate),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.mealTemplateName,
            hintText: l10n.mealTemplateNameHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !context.mounted) return;
    await nutrition.saveMealTemplateFromEntries(name: name, entries: entries);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.mealTemplateSaved)),
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
