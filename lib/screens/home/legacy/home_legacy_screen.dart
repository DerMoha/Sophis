import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/nutrition_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/unit_converter.dart';
import '../../../widgets/workout_bottom_sheet.dart';
import '../../goals_setup_screen.dart';
import '../../settings_screen.dart';
import '../../food_diary_screen.dart';
import '../../weight_tracker_screen.dart';
import '../shared/home_refresh.dart';
import '../shared/home_dashboard_vm.dart';

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
      refreshBurnedCalories(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
              if (!mounted) return;
              refreshBurnedCalories(context);
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
          return _LegacyDashboard(nutrition: nutrition);
        },
      ),
    );
  }
}

class _LegacyDashboard extends StatelessWidget {
  final NutritionProvider nutrition;

  const _LegacyDashboard({required this.nutrition});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = buildHomeDashboardVM(context, nutrition);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CalorieCard(vm: vm),
          const SizedBox(height: 16),
          _MacrosCard(vm: vm),
          const SizedBox(height: 16),
          _WaterCard(vm: vm),
          const SizedBox(height: 24),
          ...vm.mealTypes.map((mealType) => _MealExpansionTile(
                mealType: mealType,
                nutrition: nutrition,
              )),
          const SizedBox(height: 20),
          _QuickActionsWrap(l10n: l10n),
        ],
      ),
    );
  }
}

class _CalorieCard extends StatelessWidget {
  final HomeDashboardVM vm;

  const _CalorieCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(l10n.calories, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: vm.calorieProgress,
                    strokeWidth: 10,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      vm.totals['calories']!.toStringAsFixed(0),
                      style: theme.textTheme.headlineLarge,
                    ),
                    Text(
                      '/ ${vm.effectiveGoal.toStringAsFixed(0)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${vm.remaining.toStringAsFixed(0)} ${l10n.remaining}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: vm.isOverGoal
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
            if (vm.burnedCalories > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${l10n.burned('')}: ${vm.burnedCalories.toStringAsFixed(0)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.fire,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MacrosCard extends StatelessWidget {
  final HomeDashboardVM vm;

  const _MacrosCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _MacroColumn(
              label: l10n.protein,
              value: vm.totals['protein']!,
              goal: vm.goals.protein,
              color: AppTheme.protein,
            ),
            _MacroColumn(
              label: l10n.carbs,
              value: vm.totals['carbs']!,
              goal: vm.goals.carbs,
              color: AppTheme.carbs,
            ),
            _MacroColumn(
              label: l10n.fat,
              value: vm.totals['fat']!,
              goal: vm.goals.fat,
              color: AppTheme.fat,
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroColumn extends StatelessWidget {
  final String label;
  final double value;
  final double goal;
  final Color color;

  const _MacroColumn({
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)}g',
          style: TextStyle(color: color),
        ),
      ],
    );
  }
}

class _WaterCard extends StatelessWidget {
  final HomeDashboardVM vm;

  const _WaterCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final progress = (vm.waterTotal / vm.waterGoal).clamp(0.0, 1.0);

    return Card(
      elevation: 2,
      child: ListTile(
        leading: const Icon(Icons.water_drop, color: AppTheme.water),
        title: Text(l10n.water),
        subtitle: LinearProgressIndicator(
          value: progress,
          backgroundColor: AppTheme.water.withValues(alpha: 0.2),
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
            Text(UnitConverter.formatWater(vm.waterTotal, vm.unitSystem)),
          ],
        ),
      ),
    );
  }
}

class _MealExpansionTile extends StatelessWidget {
  final dynamic mealType;
  final NutritionProvider nutrition;

  const _MealExpansionTile({
    required this.mealType,
    required this.nutrition,
  });

  @override
  Widget build(BuildContext context) {
    final entries = nutrition.getEntriesByMeal(mealType.id);
    final calories = entries.fold(0.0, (sum, e) => sum + e.calories);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(mealType.icon),
        title: Text(mealType.name),
        subtitle: Text('${calories.toStringAsFixed(0)} kcal'),
        children: entries
            .map((entry) => ListTile(
                  title: Text(entry.name),
                  subtitle: Text('${entry.calories.toStringAsFixed(0)} kcal'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => nutrition.removeFoodEntry(entry.id),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _QuickActionsWrap extends StatelessWidget {
  final AppLocalizations l10n;

  const _QuickActionsWrap({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        ActionChip(
          avatar: const Icon(Icons.history),
          label: Text(l10n.foodDiary),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FoodDiaryScreen()),
          ),
        ),
        ActionChip(
          avatar: const Icon(Icons.monitor_weight),
          label: Text(l10n.weight),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WeightTrackerScreen()),
          ),
        ),
        ActionChip(
          avatar: const Icon(Icons.local_fire_department),
          label: Text(l10n.workout),
          onPressed: () => showModalBottomSheet(
            context: context,
            builder: (_) => const WorkoutBottomSheet(),
          ),
        ),
      ],
    );
  }
}
