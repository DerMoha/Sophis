import 'package:flutter/material.dart';
import 'package:sophis/ui/components/common/entry_feedback.dart';
import 'package:sophis/ui/components/draft_guard.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/utils/number_utils.dart';
import 'package:sophis/models/workout_entry.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/utils/time_utils.dart';
import 'package:sophis/ui/components/modal_sheet.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/theme/animations.dart';

class WorkoutBottomSheet extends StatefulWidget {
  final WorkoutEntry? editEntry;

  const WorkoutBottomSheet({super.key, this.editEntry});

  @override
  State<WorkoutBottomSheet> createState() => _WorkoutBottomSheetState();
}

class _WorkoutBottomSheetState extends State<WorkoutBottomSheet> {
  final _draftKey = GlobalKey<DraftGuardState>();
  final _caloriesController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isSaving = false;
  String? _caloriesError;

  @override
  void initState() {
    super.initState();
    if (widget.editEntry != null) {
      _caloriesController.text =
          widget.editEntry!.caloriesBurned.toStringAsFixed(0);
      _noteController.text = widget.editEntry!.note ?? '';
    }
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveEntry() async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context)!;
    final calories = NumberUtils.parseInput(_caloriesController.text);
    if (calories == null || calories <= 0) {
      setState(() => _caloriesError = l10n.enterValidPositiveNumber);
      return;
    }
    setState(() {
      _caloriesError = null;
      _isSaving = true;
    });
    final nutrition = context.read<NutritionProvider>();
    try {
      if (widget.editEntry != null) {
        await nutrition.updateWorkoutEntry(
          WorkoutEntry(
            id: widget.editEntry!.id,
            caloriesBurned: calories,
            timestamp: widget.editEntry!.timestamp,
            note: _noteController.text.isEmpty ? null : _noteController.text,
          ),
        );
      } else {
        await nutrition.addWorkoutEntry(
          calories,
          note: _noteController.text.isEmpty ? null : _noteController.text,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.entrySaved)),
      );
      _draftKey.currentState?.markSaved();
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.saveEntryFailed)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addPreset(int amount) {
    if (_isSaving) return;
    _caloriesController.text = amount.toString();
    _saveEntry();
  }

  Future<void> _deleteEntry(String id) async {
    final nutrition = context.read<NutritionProvider>();
    final entry =
        nutrition.workoutEntries.where((entry) => entry.id == id).firstOrNull;
    if (entry == null) return;
    await deleteEntryWithUndo(
      context,
      remove: () => nutrition.removeWorkoutEntry(id),
      restore: () => nutrition.restoreWorkoutEntry(entry),
      label: AppLocalizations.of(context)!.workout,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final isEditing = widget.editEntry != null;

    return DraftGuard(
      key: _draftKey,
      controllers: [_caloriesController, _noteController],
      hasOtherChanges: false,
      isSaving: _isSaving,
      child: ModalSheetSurface(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ModalSheetHandle(),
              ModalSheetHeader(
                icon: Icons.local_fire_department_rounded,
                iconColor: AppTheme.fire,
                iconBoxSize: 32,
                title: isEditing ? l10n.editWorkout : l10n.logWorkout,
              ),
              const SizedBox(height: 24),

              // Quick add buttons (only in non-edit mode)
              if (!isEditing)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          MediaQuery.textScalerOf(context).scale(1) > 1.3
                              ? 2
                              : 4;
                      final width =
                          (constraints.maxWidth - 12 * (columns - 1)) / columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final amount in [100, 200, 300, 500])
                            SizedBox(
                              width: width,
                              child: _QuickAddButton(
                                amount: amount,
                                onTap:
                                    _isSaving ? null : () => _addPreset(amount),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              if (!isEditing) const SizedBox(height: AppTheme.spaceLG2),

              // Custom Entry
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _caloriesController,
                      enabled: !_isSaving,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      autofocus: isEditing,
                      decoration: InputDecoration(
                        labelText: l10n.caloriesBurned,
                        errorText: _caloriesError,
                        errorMaxLines: 3,
                        prefixIcon: const Icon(
                          Icons.local_fire_department_outlined,
                          size: 20,
                        ),
                        suffixText: 'kcal',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onSubmitted: (_) => _saveEntry(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveEntry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.fire,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        child: Text(isEditing ? l10n.save : l10n.add),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceSM2),

              // Optional note
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: _noteController,
                  enabled: !_isSaving,
                  decoration: InputDecoration(
                    hintText: l10n.noteOptional,
                    prefixIcon: const Icon(Icons.note_outlined, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // History List (only in non-edit mode)
              if (!isEditing) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        l10n.today,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Consumer<NutritionProvider>(
                  builder: (context, nutrition, _) {
                    final entries = nutrition.getTodayWorkoutEntries();

                    if (entries.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppTheme.fire.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.fitness_center_outlined,
                                color: AppTheme.fire.withValues(alpha: 0.5),
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spaceSM2),
                            Text(
                              l10n.noWorkouts,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return FadeInSlide(
                          index: index,
                          delay: const Duration(milliseconds: 30),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.02),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMD),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppTheme.fire.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusXS,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.local_fire_department,
                                    color: AppTheme.fire,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${entry.caloriesBurned.toStringAsFixed(0)} kcal',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
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
                                    Navigator.pop(context);
                                    showDraftBottomSheet(
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
              ],
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  final int amount;
  final VoidCallback? onTap;

  const _QuickAddButton({
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
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
    );
  }
}
