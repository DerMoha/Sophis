import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/nutrition_provider.dart';
import '../theme/app_theme.dart';

class ActivityGraphScreen extends StatefulWidget {
  const ActivityGraphScreen({super.key});

  @override
  State<ActivityGraphScreen> createState() => _ActivityGraphScreenState();
}

class _ActivityGraphScreenState extends State<ActivityGraphScreen> {
  int _selectedDays = 7; // 7 or 30 days

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.activity),
        actions: [
          // Toggle between 7 and 30 days
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7D')),
              ButtonSegment(value: 30, label: Text('30D')),
            ],
            selected: {_selectedDays},
            onSelectionChanged: (selection) {
              setState(() => _selectedDays = selection.first);
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<NutritionProvider>(
        builder: (context, nutrition, _) {
          final data = _getHistoricalData(nutrition, _selectedDays);
          final goals = nutrition.goals;

          if (data.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 64, color: theme.disabledColor),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noActivityData,
                    style: TextStyle(color: theme.disabledColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.startLoggingMeals,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Calorie chart
                _buildChartCard(
                  title: l10n.calories,
                  data: data,
                  getValue: (d) => d.calories,
                  goalValue: goals?.calories,
                  color: theme.colorScheme.primary,
                  theme: theme,
                  l10n: l10n,
                ),
                const SizedBox(height: 16),

                // Macros summary
                _buildMacroSummary(data, goals, l10n, theme),
                const SizedBox(height: 16),

                // Protein chart
                _buildChartCard(
                  title: l10n.protein,
                  data: data,
                  getValue: (d) => d.protein,
                  goalValue: goals?.protein,
                  color: AppTheme.success,
                  theme: theme,
                  l10n: l10n,
                  unit: 'g',
                ),
                const SizedBox(height: 16),

                // Carbs chart
                _buildChartCard(
                  title: l10n.carbs,
                  data: data,
                  getValue: (d) => d.carbs,
                  goalValue: goals?.carbs,
                  color: AppTheme.warning,
                  theme: theme,
                  l10n: l10n,
                  unit: 'g',
                ),
                const SizedBox(height: 16),

                // Fat chart
                _buildChartCard(
                  title: l10n.fat,
                  data: data,
                  getValue: (d) => d.fat,
                  goalValue: goals?.fat,
                  color: AppTheme.error,
                  theme: theme,
                  l10n: l10n,
                  unit: 'g',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<DayData> _getHistoricalData(NutritionProvider nutrition, int days) {
    final result = <DayData>[];
    final now = DateTime.now();

    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      final entries = nutrition.getEntriesForDate(date);

      double calories = 0, protein = 0, carbs = 0, fat = 0;
      for (final entry in entries) {
        calories += entry.calories;
        protein += entry.protein;
        carbs += entry.carbs;
        fat += entry.fat;
      }

      result.add(DayData(
        date: date,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
      ));
    }

    return result;
  }

  Widget _buildChartCard({
    required String title,
    required List<DayData> data,
    required double Function(DayData) getValue,
    required Color color,
    required ThemeData theme,
    required AppLocalizations l10n,
    double? goalValue,
    String unit = 'kcal',
  }) {
    final values = data.map(getValue).toList();
    final maxValue = values.isNotEmpty 
        ? values.reduce((a, b) => a > b ? a : b) 
        : 0.0;
    final avgValue = values.isNotEmpty 
        ? values.reduce((a, b) => a + b) / values.length 
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                Text(
                  'Avg: ${avgValue.toStringAsFixed(0)} $unit',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (goalValue != null && goalValue > maxValue)
                      ? goalValue * 1.1
                      : maxValue * 1.1,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final day = data[groupIndex];
                        return BarTooltipItem(
                          '${DateFormat('MMM d').format(day.date)}\n${getValue(day).toStringAsFixed(0)} $unit',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < data.length) {
                            // Show only some labels to avoid crowding
                            if (_selectedDays == 7 || index % 5 == 0 || index == data.length - 1) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  DateFormat('d').format(data[index].date),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            }
                          }
                          return const SizedBox();
                        },
                        reservedSize: 28,
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: data.asMap().entries.map((entry) {
                    final value = getValue(entry.value);
                    final isGoalMet = goalValue != null && value >= goalValue;
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: value,
                          color: isGoalMet ? color : color.withValues(alpha: 0.6), // 150/255
                          width: _selectedDays == 7 ? 24 : 8,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  extraLinesData: goalValue != null
                      ? ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: goalValue,
                              color: color.withValues(alpha: 0.4), // 100/255
                              strokeWidth: 2,
                              dashArray: [5, 5],
                              label: HorizontalLineLabel(
                                show: true,
                                alignment: Alignment.topRight,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                labelResolver: (line) => l10n.goalLabel,
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
                duration: const Duration(milliseconds: 300),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroSummary(
    List<DayData> data,
    dynamic goals,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    if (data.isEmpty) return const SizedBox();

    // Calculate averages
    final avgCalories = data.map((d) => d.calories).reduce((a, b) => a + b) / data.length;
    final avgProtein = data.map((d) => d.protein).reduce((a, b) => a + b) / data.length;

    // Count days where goal was met
    int daysMetCalories = 0;
    if (goals != null) {
      for (final d in data) {
        if (d.calories >= goals.calories * 0.9 && d.calories <= goals.calories * 1.1) {
          daysMetCalories++;
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.summary, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryTile(
                    l10n.avgCalories,
                    avgCalories.toStringAsFixed(0),
                    'kcal',
                    theme.colorScheme.primary,
                    theme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryTile(
                    l10n.avgProtein,
                    avgProtein.toStringAsFixed(0),
                    'g',
                    AppTheme.success,
                    theme,
                  ),
                ),
              ],
            ),
            if (goals != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: AppTheme.success),
                  const SizedBox(width: 4),
                  Text(
                    l10n.daysOnTrack(daysMetCalories, data.length),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTile(
    String label,
    String value,
    String unit,
    Color color,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08), // 20/255
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(unit, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class DayData {
  final DateTime date;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  DayData({
    required this.date,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}
