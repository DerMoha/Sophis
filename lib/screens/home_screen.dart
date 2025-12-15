import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/nutrition_provider.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import 'goals_setup_screen.dart';
import 'settings_screen.dart';
import 'add_food_screen.dart';
import 'food_search_screen.dart';
import 'barcode_scanner_screen.dart';
import 'weight_tracker_screen.dart';
import 'recipes_screen.dart';
import 'ai_food_camera_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settings,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
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

  Widget _buildWelcomeView(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.today, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.restaurant_menu_outlined,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.welcomeTitle, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(l10n.welcomeSubtitle, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GoalsSetupScreen()),
                        ),
                        child: Text(l10n.setGoals),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
    final waterTotal = nutrition.getTodayWaterTotal();
    final waterGoal = context.read<SettingsProvider>().waterGoalMl;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Calories summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.today, style: theme.textTheme.titleMedium),
                    _buildRemainingBadge(remaining, l10n),
                  ],
                ),
                const SizedBox(height: 20),
                _buildProgressBar(
                  label: l10n.calories,
                  current: totals['calories']!,
                  goal: goals.calories,
                  color: AppTheme.accent,
                  unit: 'kcal',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildProgressBar(
                      label: l10n.protein,
                      current: totals['protein']!,
                      goal: goals.protein,
                      color: AppTheme.success,
                      unit: 'g',
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _buildProgressBar(
                      label: l10n.carbs,
                      current: totals['carbs']!,
                      goal: goals.carbs,
                      color: AppTheme.warning,
                      unit: 'g',
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _buildProgressBar(
                      label: l10n.fat,
                      current: totals['fat']!,
                      goal: goals.fat,
                      color: AppTheme.error,
                      unit: 'g',
                    )),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Water tracker
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.water_drop_outlined, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(l10n.water, style: theme.textTheme.titleMedium),
                      ],
                    ),
                    Text(
                      '${(waterTotal / 1000).toStringAsFixed(1)} / ${(waterGoal / 1000).toStringAsFixed(1)} L',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (waterTotal / waterGoal).clamp(0, 1),
                    minHeight: 8,
                    backgroundColor: Colors.blue.withAlpha(26),
                    valueColor: const AlwaysStoppedAnimation(Colors.blue),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildWaterButton(context, 250, '250ml'),
                    _buildWaterButton(context, 500, '500ml'),
                    _buildWaterButton(context, 1000, '1L'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Quick actions
        Row(
          children: [
            Expanded(
              child: _buildQuickAction(
                context,
                icon: Icons.monitor_weight_outlined,
                label: l10n.weight,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WeightTrackerScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickAction(
                context,
                icon: Icons.restaurant_menu_outlined,
                label: l10n.recipes,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RecipesScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Meals
        _buildMealSection(context, l10n, 'breakfast', l10n.breakfast, Icons.wb_twilight_outlined),
        _buildMealSection(context, l10n, 'lunch', l10n.lunch, Icons.wb_sunny_outlined),
        _buildMealSection(context, l10n, 'dinner', l10n.dinner, Icons.nights_stay_outlined),
        _buildMealSection(context, l10n, 'snack', l10n.snacks, Icons.cookie_outlined),
      ],
    );
  }

  Widget _buildRemainingBadge(double remaining, AppLocalizations l10n) {
    final isOver = remaining < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isOver ? AppTheme.error : AppTheme.success).withAlpha(26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${remaining.abs().toStringAsFixed(0)} ${isOver ? l10n.over : l10n.remaining}',
        style: TextStyle(
          color: isOver ? AppTheme.error : AppTheme.success,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildProgressBar({
    required String label,
    required double current,
    required double goal,
    required Color color,
    required String unit,
  }) {
    final progress = (current / goal).clamp(0.0, 1.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(
              '${current.toStringAsFixed(0)}/${goal.toStringAsFixed(0)}$unit',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        AnimatedProgressBar(
          value: progress,
          height: 6,
          backgroundColor: color.withAlpha(26),
          valueColor: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _buildWaterButton(BuildContext context, double ml, String label) {
    return OutlinedButton(
      onPressed: () => context.read<NutritionProvider>().addWater(ml),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.blue,
        side: BorderSide(color: Colors.blue.withAlpha(77)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(label),
    );
  }

  Widget _buildMealSection(
    BuildContext context,
    AppLocalizations l10n,
    String mealType,
    String title,
    IconData icon,
  ) {
    final entries = context.watch<NutritionProvider>().getEntriesByMeal(mealType);
    final total = entries.fold(0.0, (sum, e) => sum + e.calories);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Column(
          children: [
            ListTile(
              leading: Icon(icon),
              title: Text(title),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (total > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withAlpha(26),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${total.toStringAsFixed(0)} kcal',
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.add),
                    onSelected: (value) {
                      switch (value) {
                        case 'manual':
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AddFoodScreen(meal: mealType)),
                          );
                          break;
                        case 'search':
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => FoodSearchScreen(meal: mealType)),
                          );
                          break;
                        case 'barcode':
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => BarcodeScannerScreen(meal: mealType)),
                          );
                          break;
                        case 'ai':
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AIFoodCameraScreen(meal: mealType)),
                          );
                          break;
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'manual', child: Text('Manual entry')),
                      PopupMenuItem(value: 'search', child: Text('Search food')),
                      PopupMenuItem(value: 'barcode', child: Text('Scan barcode')),
                      PopupMenuItem(value: 'ai', child: Text('📷 AI recognition')),
                    ],
                  ),
                ],
              ),
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  l10n.noEntries,
                  style: TextStyle(color: Theme.of(context).disabledColor),
                ),
              )
            else
              ...entries.map((entry) => ListTile(
                dense: true,
                title: Text(entry.name),
                subtitle: Text(
                  'P: ${entry.protein.toStringAsFixed(0)}g | C: ${entry.carbs.toStringAsFixed(0)}g | F: ${entry.fat.toStringAsFixed(0)}g',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Text('${entry.calories.toStringAsFixed(0)} kcal'),
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l10n.delete),
                      content: Text('Delete "${entry.name}"?'),
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
                          child: Text(l10n.delete),
                        ),
                      ],
                    ),
                  );
                },
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
