import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/utils/time_utils.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/theme/animations.dart';
import 'package:sophis/ui/components/organic_components.dart';
import 'package:sophis/ui/components/workout_bottom_sheet.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final _caloriesController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _caloriesController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _saveEntry() {
    final calories = double.tryParse(_caloriesController.text);
    if (calories == null || calories <= 0) return;

    final nutrition = context.read<NutritionProvider>();

    nutrition.addWorkoutEntry(
      calories,
      note: _noteController.text.isEmpty ? null : _noteController.text,
    );

    _caloriesController.clear();
    _noteController.clear();
    FocusScope.of(context).unfocus();
  }

  void _deleteEntry(String id) {
    context.read<NutritionProvider>().removeWorkoutEntry(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workout),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: AppTheme.pagePadding,
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Quick add buttons
                FadeInSlide(
                  index: 0,
                  child: GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.add,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _QuickAddButton(
                              amount: 100,
                              onTap: () => context
                                  .read<NutritionProvider>()
                                  .addWorkoutEntry(100),
                            ),
                            _QuickAddButton(
                              amount: 200,
                              onTap: () => context
                                  .read<NutritionProvider>()
                                  .addWorkoutEntry(200),
                            ),
                            _QuickAddButton(
                              amount: 300,
                              onTap: () => context
                                  .read<NutritionProvider>()
                                  .addWorkoutEntry(300),
                            ),
                            _QuickAddButton(
                              amount: 500,
                              onTap: () => context
                                  .read<NutritionProvider>()
                                  .addWorkoutEntry(500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLG2),

                // Custom Entry
                FadeInSlide(
                  index: 1,
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
                                    AppTheme.fire,
                                    AppTheme.fire.withValues(alpha: 0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMD,
                                ),
                              ),
                              child: const Icon(
                                Icons.local_fire_department_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.logWorkout,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        largeText
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: _caloriesController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: l10n.caloriesBurned,
                                      suffixText: 'kcal',
                                      prefixIcon: const Icon(
                                        Icons.local_fire_department_outlined,
                                        size: 20,
                                      ),
                                    ),
                                    onSubmitted: (_) => _saveEntry(),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _noteController,
                                    decoration: InputDecoration(
                                      hintText: l10n.noteOptional,
                                      prefixIcon: const Icon(
                                        Icons.note_outlined,
                                        size: 20,
                                      ),
                                    ),
                                    onSubmitted: (_) => _saveEntry(),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _caloriesController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        hintText: l10n.caloriesBurned,
                                        suffixText: 'kcal',
                                        prefixIcon: const Icon(
                                          Icons.local_fire_department_outlined,
                                          size: 20,
                                        ),
                                      ),
                                      onSubmitted: (_) => _saveEntry(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      controller: _noteController,
                                      decoration: InputDecoration(
                                        hintText: l10n.noteOptional,
                                        prefixIcon: const Icon(
                                          Icons.note_outlined,
                                          size: 20,
                                        ),
                                      ),
                                      onSubmitted: (_) => _saveEntry(),
                                    ),
                                  ),
                                ],
                              ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saveEntry,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.fire,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.add, size: 20),
                            label: Text(l10n.add),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // History List
                FadeInSlide(
                  index: 2,
                  child: SectionHeader(
                    title: l10n.today,
                    icon: Icons.history_outlined,
                  ),
                ),

                Consumer<NutritionProvider>(
                  builder: (context, nutrition, _) {
                    final entries = nutrition.getTodayWorkoutEntries();

                    if (entries.isEmpty) {
                      return FadeInSlide(
                        index: 3,
                        child: EmptyState(
                          icon: Icons.fitness_center_outlined,
                          title: l10n.noWorkouts,
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return FadeInSlide(
                          index: 3 + index,
                          delay: const Duration(milliseconds: 30),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMD),
                              border: Border.all(
                                color: isDark
                                    ? CachedColors.surfaceTintDark06
                                    : CachedColors.surfaceTintLight04,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppTheme.fire.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSM,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.local_fire_department,
                                    color: AppTheme.fire,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${entry.caloriesBurned.toStringAsFixed(0)} kcal',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        entry.note ??
                                            TimeUtils.formatDateTimeTime(
                                              context,
                                              entry.timestamp,
                                            ),
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => WorkoutBottomSheet(
                                        editEntry: entry,
                                      ),
                                    );
                                  },
                                  visualDensity: VisualDensity.compact,
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color:
                                        AppTheme.error.withValues(alpha: 0.7),
                                    size: 20,
                                  ),
                                  onPressed: () => _deleteEntry(entry.id),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  final int amount;
  final VoidCallback onTap;

  const _QuickAddButton({
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 104,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.fire.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(
                color: AppTheme.fire.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: AppTheme.fire,
                  size: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  '${amount}kcal',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.fire,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
