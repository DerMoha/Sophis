import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../services/supplements_provider.dart';
import '../models/supplement.dart';
import '../theme/app_theme.dart';
import '../widgets/organic_components.dart';
import '../widgets/supplement_edit_sheet.dart';

class SupplementsScreen extends StatelessWidget {
  const SupplementsScreen({super.key});

  static const _emerald = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Consumer<SupplementsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final supplements = provider.supplements;
          final completedIds = provider.getTodayCompletedIds();

          return CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                pinned: true,
                expandedHeight: 120,
                backgroundColor: theme.colorScheme.surface,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: const Text('Supplements 💊'),
                  titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
                  expandedTitleScale: 1.3,
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
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: GlassCard(
                      padding: const EdgeInsets.all(20),
                      tint: _emerald,
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
                                    backgroundColor: theme.colorScheme
                                        .surfaceContainerHighest,
                                    valueColor: AlwaysStoppedAnimation(
                                      theme.colorScheme.surfaceContainerHighest,
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
                                        const AlwaysStoppedAnimation(_emerald),
                                  ),
                                ),
                                // Center text
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${provider.todayCompletedCount}',
                                        style:
                                            theme.textTheme.headlineMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: _emerald,
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
                                ? 'All supplements taken! 🎉'
                                : 'Today\'s Progress',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      Text(
                        'All Supplements',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${supplements.length} total',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),

              // Supplements List
              if (supplements.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(context, theme),
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
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusLG),
                              ),
                              child: const Icon(
                                Icons.delete_rounded,
                                color: Colors.red,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Supplement?'),
                                  content: Text(
                                      'Are you sure you want to delete ${supplement.name}?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text('Delete'),
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
                                      '${supplement.name} deleted'),
                                  action: SnackBarAction(
                                    label: 'Undo',
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
        backgroundColor: _emerald,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Supplement'),
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
          GestureDetector(
            onTap: () {
              if (supplement.enabled) {
                HapticFeedback.mediumImpact();
                provider.toggleCompletion(supplement.id);
              }
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? _emerald : Colors.transparent,
                border: Border.all(
                  color: isCompleted
                      ? _emerald
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
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
            activeColor: _emerald,
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
            Icon(
              Icons.medication_liquid_rounded,
              size: 80,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No supplements yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add your first supplement to start tracking',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildQuickAddButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAddButtons(BuildContext context) {
    final quickSupplements = [
      'Omega-3',
      'Vitamin D',
      'Vitamin C',
      'Creatine',
      'Magnesium',
      'Multivitamin',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: quickSupplements.map((name) {
        return OutlinedButton(
          onPressed: () {
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
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _emerald.withValues(alpha: 0.3)),
            foregroundColor: _emerald,
          ),
          child: Text(name),
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
