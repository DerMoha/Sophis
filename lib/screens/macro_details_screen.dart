import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/nutrition_goals.dart';
import '../theme/app_theme.dart';
import '../widgets/organic_components.dart';

class MacroDetailsScreen extends StatelessWidget {
  final Map<String, double> totals;
  final NutritionGoals goals;

  const MacroDetailsScreen({
    super.key,
    required this.totals,
    required this.goals,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Calculate percentages
    final proteinProgress = (totals['protein']! / goals.protein).clamp(0.0, 1.0);
    final carbsProgress = (totals['carbs']! / goals.carbs).clamp(0.0, 1.0);
    final fatProgress = (totals['fat']! / goals.fat).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.macronutrients),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Summary Header
            Text(
              l10n.macronutrients,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.trackYourProgress,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // Protein Section
            _buildMacroDeepDive(
              context,
              label: l10n.protein,
              current: totals['protein']!,
              goal: goals.protein,
              color: AppTheme.protein,
              progress: proteinProgress,
              icon: Icons.fitness_center_rounded,
            ),
            const SizedBox(height: 20),

            // Carbs Section
            _buildMacroDeepDive(
              context,
              label: l10n.carbs,
              current: totals['carbs']!,
              goal: goals.carbs,
              color: AppTheme.carbs,
              progress: carbsProgress,
              icon: Icons.bolt_rounded,
            ),
            const SizedBox(height: 20),

            // Fat Section
            _buildMacroDeepDive(
              context,
              label: l10n.fat,
              current: totals['fat']!,
              goal: goals.fat,
              color: AppTheme.fat,
              progress: fatProgress,
              icon: Icons.water_drop_rounded, // Assuming fat uses droplet or similar
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroDeepDive(
    BuildContext context, {
    required String label,
    required double current,
    required double goal,
    required Color color,
    required double progress,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final remaining = goal - current;
    final isOver = remaining < 0;

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "${current.toStringAsFixed(1)} / ${goal.toStringAsFixed(1)} g",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              RadialProgress(
                value: progress,
                size: 60,
                strokeWidth: 6,
                color: color,
                showGlow: false,
                child: Text(
                  "${(progress * 100).toInt()}%",
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Enhanced Progress Bar
          Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isOver ? l10n.over : l10n.remaining,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isOver ? AppTheme.error : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                "${remaining.abs().toStringAsFixed(1)} g",
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isOver ? AppTheme.error : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
