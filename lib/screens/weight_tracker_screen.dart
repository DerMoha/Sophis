import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/nutrition_provider.dart';
import '../theme/app_theme.dart';

class WeightTrackerScreen extends StatefulWidget {
  const WeightTrackerScreen({super.key});

  @override
  State<WeightTrackerScreen> createState() => _WeightTrackerScreenState();
}

class _WeightTrackerScreenState extends State<WeightTrackerScreen> {
  final _weightController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _weightController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _addWeight() {
    final weight = double.tryParse(_weightController.text);
    if (weight == null || weight <= 0) return;

    context.read<NutritionProvider>().addWeight(
      weight,
      note: _noteController.text.isEmpty ? null : _noteController.text,
    );

    _weightController.clear();
    _noteController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.weight),
      ),
      body: Consumer<NutritionProvider>(
        builder: (context, nutrition, _) {
          final entries = nutrition.weightEntries;
          final latest = nutrition.latestWeight;
          final profile = nutrition.profile;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Add weight card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Log Weight', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _weightController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Weight (kg)',
                                suffixText: 'kg',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _noteController,
                              decoration: const InputDecoration(
                                labelText: 'Note (optional)',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _addWeight,
                          child: Text(l10n.add),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Current stats
              if (latest != null || profile?.targetWeight != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        if (latest != null)
                          _buildStat('Current', '${latest.weightKg.toStringAsFixed(1)} kg'),
                        if (profile?.targetWeight != null)
                          _buildStat('Goal', '${profile!.targetWeight!.toStringAsFixed(1)} kg'),
                        if (latest != null && profile?.targetWeight != null)
                          _buildStat(
                            'To Go',
                            '${(latest.weightKg - profile!.targetWeight!).abs().toStringAsFixed(1)} kg',
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // Chart
              if (entries.length >= 2)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Progress', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: _buildChart(entries.reversed.take(30).toList()),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // History
              Text('History', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (entries.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      l10n.noEntries,
                      style: TextStyle(color: theme.disabledColor),
                    ),
                  ),
                )
              else
                ...entries.map((entry) => Card(
                  child: ListTile(
                    title: Text('${entry.weightKg.toStringAsFixed(1)} kg'),
                    subtitle: Text(
                      _formatDate(entry.timestamp) +
                          (entry.note != null ? ' • ${entry.note}' : ''),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                      onPressed: () => _confirmDelete(entry.id),
                    ),
                  ),
                )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Theme.of(context).disabledColor)),
      ],
    );
  }

  Widget _buildChart(List entries) {
    if (entries.isEmpty) return const SizedBox();
    final theme = Theme.of(context);

    final spots = <FlSpot>[];
    for (var i = 0; i < entries.length; i++) {
      spots.add(FlSpot(i.toDouble(), entries[i].weightKg));
    }

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 2;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 2;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: theme.colorScheme.primary,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withAlpha(26),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  void _confirmDelete(String id) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: const Text('Delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              context.read<NutritionProvider>().removeWeightEntry(id);
              Navigator.pop(ctx);
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}
