import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/supplements_provider.dart';
import '../../../models/supplement.dart';
import '../theme/animations.dart';
import '../theme/app_theme.dart';
import '../components/organic_components.dart';
import '../components/supplement_edit_sheet.dart';

class SupplementsScreen extends StatefulWidget {
  const SupplementsScreen({super.key});

  @override
  State<SupplementsScreen> createState() => _SupplementsScreenState();
}

class _SupplementsScreenState extends State<SupplementsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return Scaffold(
      body: Consumer<SupplementsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final supplements = provider.supplements;
          final completedIds = provider.getTodayCompletedIds();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // App Bar
              SliverAppBar(
                pinned: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                title: Text(l10n.supplements),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => provider.refresh(),
                  ),
                ],
              ),

              // Today's Progress Card
              if (supplements.isNotEmpty)
                SliverToBoxAdapter(
                  child: FadeInSlide(
                    index: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Circular progress
                            SizedBox(
                              width: 100,
                              height: 100,
                              child: Stack(
                                children: [
                                  // Background circle
                                  SizedBox.expand(
                                    child: CircularProgressIndicator(
                                      value: 1.0,
                                      strokeWidth: 8,
                                      backgroundColor: theme
                                          .colorScheme.surfaceContainerHighest,
                                      valueColor: AlwaysStoppedAnimation(
                                        theme.colorScheme
                                            .surfaceContainerHighest,
                                      ),
                                    ),
                                  ),
                                  // Progress circle
                                  SizedBox.expand(
                                    child: CircularProgressIndicator(
                                      value: provider.todayTotalCount > 0
                                          ? provider.todayCompletedCount /
                                              provider.todayTotalCount
                                          : 0.0,
                                      strokeWidth: 8,
                                      backgroundColor: Colors.transparent,
                                      valueColor:
                                          AlwaysStoppedAnimation(accentColor),
                                    ),
                                  ),
                                  // Center text
                                  Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${provider.todayCompletedCount}',
                                          style: theme.textTheme.headlineMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: accentColor,
                                          ),
                                        ),
                                        Text(
                                          'of ${provider.todayTotalCount}',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              provider.todayCompletedCount ==
                                          provider.todayTotalCount &&
                                      provider.todayTotalCount > 0
                                  ? l10n.supplementsTakenAll
                                  : l10n.todaysProgress,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Section Header
              SliverToBoxAdapter(
                child: FadeInSlide(
                  index: 1,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: SectionHeader(
                      title: l10n.allSupplements,
                      trailing: Text(
                        l10n.supplementsTotalCount(supplements.length),
                        style: theme.textTheme.bodySmall,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),

              // Supplements List
              if (supplements.isEmpty)
                SliverFillRemaining(
                  child: FadeInSlide(
                    index: 2,
                    child: _buildEmptyState(context, theme),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverReorderableList(
                    itemCount: supplements.length,
                    onReorder: (oldIndex, newIndex) {
                      provider.reorderSupplements(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final supplement = supplements[index];
                      final isCompleted = completedIds.contains(supplement.id);

                      return ReorderableDragStartListener(
                        key: ValueKey(supplement.id),
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Dismissible(
                            key: ValueKey('dismissible_${supplement.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusLG),
                              ),
                              child: const Icon(
                                Icons.delete_rounded,
                                color: AppTheme.error,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(l10n.deleteSupplementTitle),
                                  content: Text(
                                    l10n.deleteSupplementConfirmation(
                                      supplement.name,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(l10n.cancel),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.error,
                                      ),
                                      child: Text(l10n.delete),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (direction) {
                              provider.deleteSupplement(supplement.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.supplementDeleted(supplement.name),
                                  ),
                                  action: SnackBarAction(
                                    label: l10n.undo,
                                    onPressed: () {
                                      provider.addSupplement(supplement);
                                    },
                                  ),
                                ),
                              );
                            },
                            child: _buildSupplementCard(
                              context,
                              theme,
                              supplement,
                              isCompleted,
                              provider,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.addSupplement),
      ),
    );
  }

  Widget _buildSupplementCard(
    BuildContext context,
    ThemeData theme,
    Supplement supplement,
    bool isCompleted,
    SupplementsProvider provider,
  ) {
    final accentColor = theme.colorScheme.primary;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Drag handle
          Icon(
            Icons.drag_handle_rounded,
            color: theme.textTheme.bodySmall?.color,
            size: 20,
          ),
          const SizedBox(width: 12),

          // Checkbox
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              onTap: supplement.enabled
                  ? () {
                      HapticFeedback.mediumImpact();
                      provider.toggleCompletion(supplement.id);
                    }
                  : null,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isCompleted ? accentColor : Colors.transparent,
                      border: Border.all(
                        color: isCompleted
                            ? accentColor
                            : theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                    ),
                    child: isCompleted
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supplement.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                if (supplement.reminderTime != null)
                  Row(
                    children: [
                      Icon(
                        Icons.alarm_rounded,
                        size: 14,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        supplement.reminderTime!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Enabled switch
          Switch(
            value: supplement.enabled,
            onChanged: (value) {
              provider.updateSupplement(
                supplement.copyWith(enabled: value),
              );
            },
            activeThumbColor: accentColor,
          ),

          // Edit button
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            iconSize: 20,
            onPressed: () => _showEditSheet(context, supplement),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EmptyState(
              icon: Icons.medication_liquid_rounded,
              title: 'No supplements yet',
              subtitle: 'Add your first supplement to start tracking',
            ),
            const SizedBox(height: 32),
            _buildQuickAddButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAddButtons(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    final quickSupplements = [
      'Omega-3',
      'Vitamin D',
      'Vitamin C',
      'Creatine',
      'Magnesium',
      'Multivitamin',
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: quickSupplements.map((name) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              final supplement = Supplement(
                id: const Uuid().v4(),
                name: name,
                reminderTime: '09:00',
                enabled: true,
                sortOrder: 0,
                createdAt: DateTime.now(),
              );
              context.read<SupplementsProvider>().addSupplement(supplement);
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                name,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SupplementEditSheet(),
    );
  }

  void _showEditSheet(BuildContext context, Supplement supplement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SupplementEditSheet(supplement: supplement),
    );
  }
}
