import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/app_settings.dart';
import '../services/nutrition_provider.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../utils/unit_converter.dart';
import '../widgets/organic_components.dart';

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
    final inputValue = double.tryParse(_weightController.text);
    if (inputValue == null || inputValue <= 0) return;

    // Convert from display unit to kg for storage
    final unitSystem = context.read<SettingsProvider>().unitSystem;
    final weightKg = UnitConverter.inputToKg(inputValue, unitSystem);

    context.read<NutritionProvider>().addWeight(
          weightKg,
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
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 100,
            floating: true,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
              title: Text(
                l10n.weight,
                style: theme.textTheme.headlineMedium,
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: Consumer2<NutritionProvider, SettingsProvider>(
              builder: (context, nutrition, settings, _) {
                final entries = nutrition.weightEntries;
                final latest = nutrition.latestWeight;
                final profile = nutrition.profile;
                final unitSystem = settings.unitSystem;
                final weightLabel = unitSystem == UnitSystem.imperial
                    ? l10n.weightLb
                    : l10n.weightKg;
                final weightUnit = UnitConverter.weightUnit(unitSystem);

                return SliverList(
                  delegate: SliverChildListDelegate([
                    // Add weight card
                    FadeInSlide(
                      index: 0,
                      child: OrganicCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        theme.colorScheme.primary,
                                        theme.colorScheme.primary
                                            .withOpacity(0.7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.monitor_weight_outlined,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.logWeight,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    Text(
                                      l10n.trackYourProgress,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _weightController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: weightLabel,
                                      suffixText: weightUnit,
                                      prefixIcon: const Icon(
                                          Icons.scale_outlined,
                                          size: 20),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: _noteController,
                                    decoration: InputDecoration(
                                      labelText: l10n.noteOptional,
                                      prefixIcon: const Icon(
                                          Icons.note_outlined,
                                          size: 20),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _addWeight,
                                icon: const Icon(Icons.add, size: 20),
                                label: Text(l10n.add),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Current stats
                    if (latest != null || profile?.targetWeight != null)
                      FadeInSlide(
                        index: 1,
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(
                              vertical: 24, horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (latest != null)
                                _WeightStat(
                                  label: l10n.current,
                                  valueKg: latest.weightKg,
                                  color: theme.colorScheme.primary,
                                  unitSystem: unitSystem,
                                ),
                              if (profile?.targetWeight != null) ...[
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: theme.colorScheme.outline
                                      .withOpacity(0.2),
                                ),
                                _WeightStat(
                                  label: l10n.goal,
                                  valueKg: profile!.targetWeight!,
                                  color: AppTheme.success,
                                  unitSystem: unitSystem,
                                ),
                              ],
                              if (latest != null &&
                                  profile?.targetWeight != null) ...[
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: theme.colorScheme.outline
                                      .withOpacity(0.2),
                                ),
                                _WeightStat(
                                  label: l10n.toGo,
                                  valueKg: (latest.weightKg -
                                          profile!.targetWeight!)
                                      .abs(),
                                  color: AppTheme.warning,
                                  unitSystem: unitSystem,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Chart
                    if (entries.length >= 2)
                      FadeInSlide(
                        index: 2,
                        child: GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.insights_outlined,
                                    size: 20,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(l10n.progress,
                                      style: theme.textTheme.titleMedium),
                                ],
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 200,
                                child:
                                    _buildChart(entries.reversed.take(30).toList(), unitSystem),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // History
                    FadeInSlide(
                      index: 3,
                      child: SectionHeader(
                        title: l10n.history,
                        icon: Icons.history_outlined,
                      ),
                    ),

                    if (entries.isEmpty)
                      FadeInSlide(
                        index: 4,
                        child: EmptyState(
                          icon: Icons.monitor_weight_outlined,
                          title: l10n.noEntries,
                        ),
                      )
                    else
                      ...entries.asMap().entries.map((entry) => FadeInSlide(
                            index: 4 + entry.key,
                            child: _WeightEntryTile(
                              weightKg: entry.value.weightKg,
                              date: entry.value.timestamp,
                              note: entry.value.note,
                              unitSystem: unitSystem,
                              onDelete: () => _confirmDelete(entry.value.id),
                            ),
                          )),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List entries, UnitSystem unitSystem) {
    if (entries.isEmpty) return const SizedBox();
    final theme = Theme.of(context);

    final spots = <FlSpot>[];
    for (var i = 0; i < entries.length; i++) {
      // Convert to display unit for chart
      final displayWeight = UnitConverter.displayWeight(entries[i].weightKg, unitSystem);
      spots.add(FlSpot(i.toDouble(), displayWeight));
    }

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 2;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 2;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.colorScheme.outline.withOpacity(0.1),
            strokeWidth: 1,
          ),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: theme.colorScheme.primary,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 5,
                color: theme.colorScheme.primary,
                strokeWidth: 2,
                strokeColor: theme.colorScheme.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.2),
                  theme.colorScheme.primary.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => theme.colorScheme.surface,
            tooltipRoundedRadius: 12,
            getTooltipItems: (spots) => spots
                .map((spot) => LineTooltipItem(
                      '${spot.y.toStringAsFixed(1)} ${UnitConverter.weightUnit(unitSystem)}',
                      TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(String id) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteEntryConfirmation),
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
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

class _WeightStat extends StatelessWidget {
  final String label;
  final double valueKg;
  final Color color;
  final UnitSystem unitSystem;

  const _WeightStat({
    required this.label,
    required this.valueKg,
    required this.color,
    required this.unitSystem,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayValue = UnitConverter.displayWeight(valueKg, unitSystem);
    final unit = UnitConverter.weightUnit(unitSystem);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedNumber(
          value: displayValue,
          suffix: unit,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
          suffixStyle: theme.textTheme.bodyMedium?.copyWith(
            color: color.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _WeightEntryTile extends StatelessWidget {
  final double weightKg;
  final DateTime date;
  final String? note;
  final UnitSystem unitSystem;
  final VoidCallback onDelete;

  const _WeightEntryTile({
    required this.weightKg,
    required this.date,
    required this.note,
    required this.unitSystem,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayWeight = UnitConverter.displayWeight(weightKg, unitSystem);
    final unit = UnitConverter.weightUnit(unitSystem);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.monitor_weight_outlined,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${displayWeight.toStringAsFixed(1)} $unit',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatDate(date) + (note != null ? ' • $note' : ''),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: AppTheme.error.withOpacity(0.7),
              size: 20,
            ),
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}
