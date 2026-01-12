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
    final proteinProgress = totals['protein']! / goals.protein;
    final carbsProgress = totals['carbs']! / goals.carbs;
    final fatProgress = totals['fat']! / goals.fat;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.macronutrients),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 100, 24, 100), // Top padding for AppBar clearance, Bottom for visual lift
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Removed top spacing to allow true centering

            // Protein Section
            _buildMacroDeepDive(
              context,
              label: l10n.protein,
              current: totals['protein']!,
              goal: goals.protein,
              color: AppTheme.protein,
              progress: proteinProgress,
              icon: Icons.fitness_center_rounded,
              positiveExcess: true,
              excessColor: AppTheme.success,
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
    bool positiveExcess = false,
    Color? excessColor,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final remaining = goal - current;
    final isOver = remaining < 0;
    
    final finalExcessColor = excessColor ?? AppTheme.error;
    final statusText = isOver 
        ? (positiveExcess ? "Goal exceeding" : l10n.over) // Or specific "Extra" text 
        : l10n.remaining;
    final statusColor = isOver 
        ? finalExcessColor 
        : theme.colorScheme.onSurfaceVariant;

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
              const Spacer(),
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  children: [
                    // Main Progress
                    RadialProgress(
                      value: progress.clamp(0.0, 1.0),
                      size: 60,
                      strokeWidth: 6,
                      color: color,
                      showGlow: false,
                    ),
                    // Excess Progress (Red Overlay)
                    if (isOver)
                      RadialProgress(
                        value: (progress - 1.0).clamp(0.0, 1.0),
                        size: 60,
                        strokeWidth: 6,
                        color: finalExcessColor,
                        backgroundColor: Colors.transparent,
                        showGlow: false,
                      ),
                    // Center Text
                    Center(
                      child: Text(
                        "${(progress * 100).toInt()}%",
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isOver ? finalExcessColor : color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Enhanced Progress Bar
          // Enhanced Scaled Progress Bar
          LayoutBuilder(
            builder: (context, constraints) {
              // Calculate scaling
              // If over, we scale so the total bar is visible (up to a reasonable limit, e.g. 150%)
              // If under, we scale so 100% is the full width (Goal = full width)
              
              const double minScale = 1.0; 
              // If progress > 1.0, scale max to progress. Add buffer? No, let's fit it.
              // We want the 'Goal' mark to be visible.
              // Let's settle on: Total Width represents max(Target, Current).
              
              final double maxValue = progress > 1.0 ? progress : 1.0;
              final double goalPosition = 1.0 / maxValue; // Where the goal line falls (0.0 - 1.0)
              final double currentPosition = progress / maxValue;

              // If progress is huge (e.g. 500%), the goal line becomes tiny. 
              // We might want to cap visualization at 200%? 
              // For now, simple scaling.

              return Container(
                height: 12,
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.none,
                  children: [
                    // Goal Marker (Background fill up to goal)
                    // Actually, let's make the background track opaque primarily relative to goal?
                    // No, keeping it simple:
                    
                    // 1. Base Content (Macro Color) - Up to Goal or Current, whichever is smaller
                    FractionallySizedBox(
                      widthFactor: progress > 1.0 ? goalPosition : currentPosition,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.horizontal(
                            left: const Radius.circular(6),
                            right: isOver ? Radius.zero : const Radius.circular(6),
                          ),
                        ),
                      ),
                    ),

                    // 2. Excess Content (Error/Custom Color) - From Goal to Current
                    if (isOver)
                       Padding(
                        padding: EdgeInsets.only(left: constraints.maxWidth * goalPosition),
                         child: Container(
                           height: 12,
                           // Width is the remainder
                           width: constraints.maxWidth * (currentPosition - goalPosition),
                           decoration: BoxDecoration(
                             color: finalExcessColor,
                             borderRadius: const BorderRadius.horizontal(
                               right: Radius.circular(6),
                             ),
                             boxShadow: [
                               BoxShadow(
                                 color: finalExcessColor.withOpacity(0.4),
                                 blurRadius: 8,
                                 offset: const Offset(0, 2),
                               ),
                             ],
                           ),
                         ),
                       ),
                       
                    // 3. Goal Marker Line (if over, to separate blue and red clearly)
                    if (isOver)
                      Positioned(
                        left: constraints.maxWidth * goalPosition,
                        child: Container(
                          width: 2,
                          height: 12,
                          color: Theme.of(context).cardColor, // Use card color as separator
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                statusText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                "${remaining.abs().toStringAsFixed(1)} g",
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isOver ? finalExcessColor : theme.colorScheme.onSurface,
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
