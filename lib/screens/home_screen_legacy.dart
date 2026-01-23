import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/app_settings.dart';
import '../services/nutrition_provider.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/unit_converter.dart';
import '../widgets/organic_components.dart'; // Keeping for some base widgets, but will use Card mostly
import 'goals_setup_screen.dart';
import 'settings_screen.dart';
import 'food_diary_screen.dart';
import 'meal_planner_screen.dart';
import 'weight_tracker_screen.dart';
import 'recipes_screen.dart';
import 'activity_graph_screen.dart';
import 'share_meal_screen.dart'; // Deep links might need this
import '../widgets/water_details_sheet.dart';
import '../widgets/workout_bottom_sheet.dart';
import 'macro_details_screen.dart';

class HomeScreenLegacy extends StatefulWidget {
  const HomeScreenLegacy({super.key});

  @override
  State<HomeScreenLegacy> createState() => _HomeScreenLegacyState();
}

class _HomeScreenLegacyState extends State<HomeScreenLegacy> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshBurnedCalories();
    });
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
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _refreshBurnedCalories();
            },
          ),
        ],
      ),
      body: Consumer<NutritionProvider>(
        builder: (context, nutrition, _) {
          if (nutrition.goals == null) {
            return Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GoalsSetupScreen()),
                ),
                child: Text(l10n.setGoals),
              ),
            );
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
    final totals = nutrition.getTodayTotals();
    final goals = nutrition.goals!;
    final remaining = nutrition.getRemainingCalories();
    final burnedCalories = nutrition.burnedCalories;
    final settings = context.watch<SettingsProvider>();
    final waterTotal = nutrition.getTodayWaterTotal();
    final waterGoal = settings.waterGoalMl;

    final effectiveGoal = goals.calories + burnedCalories;
    final calorieProgress =
        (totals['calories']! / effectiveGoal).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Calorie Card
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    l10n.calories,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: calorieProgress,
                          strokeWidth: 10,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            totals['calories']!.toStringAsFixed(0),
                            style: theme.textTheme.headlineLarge,
                          ),
                          Text(
                            '/ ${effectiveGoal.toStringAsFixed(0)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${remaining.toStringAsFixed(0)} ${l10n.remaining}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: remaining < 0
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
                  if (burnedCalories > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${l10n.burned('')}: ${burnedCalories.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppTheme.fire),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Macros
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegacyMacro(l10n.protein, totals['protein']!,
                      goals.protein, AppTheme.protein),
                  _buildLegacyMacro(l10n.carbs, totals['carbs']!, goals.carbs,
                      AppTheme.carbs),
                  _buildLegacyMacro(
                      l10n.fat, totals['fat']!, goals.fat, AppTheme.fat),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Water
          Card(
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.water_drop, color: AppTheme.water),
              title: Text(l10n.water),
              subtitle: LinearProgressIndicator(
                value: (waterTotal / waterGoal).clamp(0.0, 1.0),
                backgroundColor: AppTheme.water.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.water),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () =>
                        context.read<NutritionProvider>().addWater(250),
                  ),
                  Text(UnitConverter.formatWater(
                      waterTotal, settings.unitSystem)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Meals List
          ...settings.mealTypes.map((mealType) {
            final calories = nutrition
                .getEntriesByMeal(mealType.id)
                .fold(0.0, (sum, e) => sum + e.calories);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: Icon(mealType.icon),
                title: Text(mealType.name),
                subtitle: Text('${calories.toStringAsFixed(0)} kcal'),
                children: nutrition.getEntriesByMeal(mealType.id).map((entry) {
                  return ListTile(
                    title: Text(entry.name),
                    subtitle: Text('${entry.calories.toStringAsFixed(0)} kcal'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => nutrition.removeFoodEntry(entry.id),
                    ),
                  );
                }).toList(),
              ),
            );
          }).toList(),

          const SizedBox(height: 20),

          // Legacy Links
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ActionChip(
                avatar: const Icon(Icons.history),
                label: Text(l10n.foodDiary),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const FoodDiaryScreen())),
              ),
              ActionChip(
                avatar: const Icon(Icons.monitor_weight),
                label: Text(l10n.weight),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const WeightTrackerScreen())),
              ),
              ActionChip(
                avatar: const Icon(Icons.local_fire_department),
                label: Text(l10n.workout),
                onPressed: () => showModalBottomSheet(
                    context: context,
                    builder: (_) => const WorkoutBottomSheet()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyMacro(
      String label, double value, double goal, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('${value.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)}g',
            style: TextStyle(color: color)),
      ],
    );
  }
}
