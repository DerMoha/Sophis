import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/app_settings.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';

class DashboardSettingsScreen extends StatelessWidget {
  const DashboardSettingsScreen({super.key});

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
                l10n.customizeDashboard,
                style: theme.textTheme.headlineMedium,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: () {
                    context.read<SettingsProvider>().resetDashboardCards();
                  },
                  child: Text(
                    l10n.resetToDefault,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: Consumer<SettingsProvider>(
              builder: (context, settings, _) {
                final cards = settings.dashboardCards;

                return SliverList(
                  delegate: SliverChildListDelegate([
                    FadeInSlide(
                      index: 0,
                      child: Text(
                        l10n.dragToReorder,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Reorderable List
                    FadeInSlide(
                      index: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.1),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: cards.length,
                          onReorder: (oldIndex, newIndex) {
                            settings.reorderDashboardCards(oldIndex, newIndex);
                          },
                          itemBuilder: (context, index) {
                            final card = cards[index];
                            return _DashboardCardTile(
                              key: ValueKey(card.id),
                              card: card,
                              index: index,
                              onToggleVisibility: () {
                                settings.toggleDashboardCardVisibility(card.id);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCardTile extends StatelessWidget {
  final DashboardCard card;
  final int index;
  final VoidCallback onToggleVisibility;

  const _DashboardCardTile({
    super.key,
    required this.card,
    required this.index,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    final cardInfo = _getCardInfo(card.id, l10n);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: Material(
        color: card.visible
            ? Colors.transparent
            : (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: card.visible
                  ? cardInfo.color.withOpacity(0.1)
                  : theme.colorScheme.outline.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              cardInfo.icon,
              color: card.visible
                  ? cardInfo.color
                  : theme.colorScheme.outline,
              size: 20,
            ),
          ),
          title: Text(
            cardInfo.label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: card.visible
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            card.visible ? l10n.visible : l10n.hidden,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Visibility toggle
              Switch(
                value: card.visible,
                onChanged: (_) => onToggleVisibility(),
                activeColor: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              // Drag handle
              ReorderableDragStartListener(
                index: index,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.drag_handle,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _CardInfo _getCardInfo(String id, AppLocalizations l10n) {
    switch (id) {
      case DashboardCardIds.foodDiary:
        return _CardInfo(
          label: l10n.foodDiary,
          icon: Icons.history_rounded,
          color: const Color(0xFF3B82F6), // Primary blue
        );
      case DashboardCardIds.mealPlanner:
        return _CardInfo(
          label: l10n.mealPlanner,
          icon: Icons.calendar_month_outlined,
          color: const Color(0xFF8B5CF6), // Purple
        );
      case DashboardCardIds.weight:
        return _CardInfo(
          label: l10n.weight,
          icon: Icons.monitor_weight_outlined,
          color: const Color(0xFF10B981), // Green
        );
      case DashboardCardIds.recipes:
        return _CardInfo(
          label: l10n.recipes,
          icon: Icons.menu_book_outlined,
          color: const Color(0xFFF59E0B), // Amber
        );
      case DashboardCardIds.activity:
        return _CardInfo(
          label: l10n.activity,
          icon: Icons.insights_outlined,
          color: const Color(0xFF06B6D4), // Cyan
        );
      case DashboardCardIds.workout:
        return _CardInfo(
          label: l10n.workout,
          icon: Icons.local_fire_department_rounded,
          color: AppTheme.fire,
        );
      default:
        return _CardInfo(
          label: id,
          icon: Icons.widgets_outlined,
          color: const Color(0xFF6B7280), // Gray
        );
    }
  }
}

class _CardInfo {
  final String label;
  final IconData icon;
  final Color color;

  const _CardInfo({
    required this.label,
    required this.icon,
    required this.color,
  });
}
