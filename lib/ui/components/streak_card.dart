import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_stats.dart';
import '../services/nutrition_provider.dart';
import '../l10n/generated/app_localizations.dart';
import 'organic_components.dart';

/// Compact streak display card for home screen
class StreakCard extends StatelessWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<NutritionProvider>();
    final stats = provider.userStats;
    final l10n = AppLocalizations.of(context)!;

    // Only show if streak >= 2
    if (stats.currentStreak < 2) {
      return const SizedBox.shrink();
    }

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () => _showAchievementsModal(context, stats, l10n, theme),
      child: Row(
        children: [
          // Fire emoji with glow effect
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                '🔥',
                style: TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Streak text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.dayStreak(stats.currentStreak),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (stats.longestStreak > stats.currentStreak)
                  Text(
                    l10n.longestStreak(stats.longestStreak),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          
          // Achievement count badge
          if (stats.achievements.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    '${stats.achievements.length}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            color: theme.disabledColor,
          ),
        ],
      ),
    );
  }

  void _showAchievementsModal(
    BuildContext context,
    UserStats stats,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AchievementsSheet(stats: stats, l10n: l10n),
    );
  }
}

class _AchievementsSheet extends StatelessWidget {
  final UserStats stats;
  final AppLocalizations l10n;

  const _AchievementsSheet({required this.stats, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Text(
                  l10n.achievements,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.totalDaysLogged(stats.totalDaysLogged),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),

            // Achievement grid
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _AchievementBadge(
                  id: Achievements.firstLog,
                  emoji: '🌟',
                  label: l10n.achievementFirstLog,
                  unlocked: stats.achievements.contains(Achievements.firstLog),
                ),
                _AchievementBadge(
                  id: Achievements.threeDayStreak,
                  emoji: '🔥',
                  label: l10n.achievement3Days,
                  unlocked: stats.achievements.contains(Achievements.threeDayStreak),
                ),
                _AchievementBadge(
                  id: Achievements.weekWarrior,
                  emoji: '⚔️',
                  label: l10n.achievement7Days,
                  unlocked: stats.achievements.contains(Achievements.weekWarrior),
                ),
                _AchievementBadge(
                  id: Achievements.twoWeekStreak,
                  emoji: '🎯',
                  label: l10n.achievement14Days,
                  unlocked: stats.achievements.contains(Achievements.twoWeekStreak),
                ),
                _AchievementBadge(
                  id: Achievements.monthlyMaster,
                  emoji: '👑',
                  label: l10n.achievement30Days,
                  unlocked: stats.achievements.contains(Achievements.monthlyMaster),
                ),
                _AchievementBadge(
                  id: Achievements.centurion,
                  emoji: '💯',
                  label: l10n.achievement100Days,
                  unlocked: stats.achievements.contains(Achievements.centurion),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final String id;
  final String emoji;
  final String label;
  final bool unlocked;

  const _AchievementBadge({
    required this.id,
    required this.emoji,
    required this.label,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: unlocked
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : theme.disabledColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.disabledColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Text(
            emoji,
            style: TextStyle(
              fontSize: 28,
              color: unlocked ? null : Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: unlocked
                  ? theme.colorScheme.onSurface
                  : theme.disabledColor,
            ),
          ),
        ],
      ),
    );
  }
}
