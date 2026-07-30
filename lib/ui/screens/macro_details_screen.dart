import 'package:flutter/material.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/nutrition_totals.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/components/organic_components.dart';
import 'package:sophis/ui/theme/animations.dart';

class MacroDetailsScreen extends StatelessWidget {
  final NutritionTotals totals;
  final NutritionGoals goals;

  const MacroDetailsScreen({
    super.key,
    required this.totals,
    required this.goals,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Calculate percentages
    final proteinProgress = totals.protein / goals.protein;
    final carbsProgress = totals.carbs / goals.carbs;
    final fatProgress = totals.fat / goals.fat;
    final fiberProgress = goals.fiber > 0 ? totals.fiber / goals.fiber : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.macronutrients),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spaceLG,
          100,
          AppTheme.spaceLG,
          100,
        ),
        child: Column(
          children: [
            // Protein Section
            FadeInSlide(
              index: 0,
              child: _buildMacroDeepDive(
                context,
                label: l10n.protein,
                current: totals.protein,
                goal: goals.protein,
                color: AppTheme.protein,
                progress: proteinProgress,
                icon: Icons.fitness_center_rounded,
                positiveExcess: true,
                excessColor: AppTheme.success,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLG2),

            // Carbs Section
            FadeInSlide(
              index: 1,
              child: _buildMacroDeepDive(
                context,
                label: l10n.carbs,
                current: totals.carbs,
                goal: goals.carbs,
                color: AppTheme.carbs,
                progress: carbsProgress,
                icon: Icons.bolt_rounded,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLG2),

            // Fat Section
            FadeInSlide(
              index: 2,
              child: _buildMacroDeepDive(
                context,
                label: l10n.fat,
                current: totals.fat,
                goal: goals.fat,
                color: AppTheme.fat,
                progress: fatProgress,
                icon: Icons.water_drop_rounded,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLG2),

            // Fiber Section
            if (goals.fiber > 0)
              FadeInSlide(
                index: 3,
                child: _buildMacroDeepDive(
                  context,
                  label: l10n.fiber,
                  current: totals.fiber,
                  goal: goals.fiber,
                  color: AppTheme.fiber,
                  progress: fiberProgress,
                  icon: Icons.grain_rounded,
                ),
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
    bool positiveExcess = false,
    Color? excessColor,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final remaining = goal - current;
    final isOver = remaining < 0;
    final isTier2 = progress > 2.0;
    final isCapped = progress >= AppTheme.macroExcessCap;

    // Tier 2 is always alarming red, regardless of positiveExcess.
    const tier2Color = AppTheme.error;
    final finalExcessColor = excessColor ?? AppTheme.error;
    final displayExcessColor = isTier2 ? tier2Color : finalExcessColor;
    final statusText = isOver
        ? (positiveExcess ? l10n.goalExceeded : l10n.over)
        : l10n.remaining;
    final statusColor =
        isOver ? displayExcessColor : theme.colorScheme.onSurfaceVariant;

    final int percentValue = (progress * 100).round().clamp(0, 999);
    final String percentText = isCapped ? '>300%' : '$percentValue%';

    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spaceLG),
      child: Column(
        children: [
          Wrap(
            spacing: AppTheme.spaceMD,
            runSpacing: AppTheme.spaceMD,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceSM),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: AppTheme.spaceMD),
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
                    '${current.toStringAsFixed(1)} / ${goal.toStringAsFixed(1)} g',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: AppTheme.macroRingContainerSize,
                height: AppTheme.macroRingContainerSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Main Progress
                    RadialProgress(
                      value: progress.clamp(0.0, 1.0),
                      size: AppTheme.macroRingInnerSize,
                      strokeWidth: AppTheme.macroRingInnerStroke,
                      color: color,
                      showGlow: false,
                    ),
                    // Excess Progress (Outer Ring) — tier 1 (100-200%)
                    if (isOver)
                      RadialProgress(
                        value: (progress - 1.0).clamp(0.0, 1.0),
                        size: AppTheme.macroRingOuterSize,
                        strokeWidth: AppTheme.macroRingOuterStroke,
                        color: finalExcessColor,
                        backgroundColor: Colors.transparent,
                        showGlow: false,
                      ),
                    // Excess Progress (Tier-2 Outer Ring) — 200-300%, always red
                    if (isTier2)
                      RadialProgress(
                        value: (progress - 2.0).clamp(0.0, 1.0),
                        size: AppTheme.macroRingTier2Size,
                        strokeWidth: AppTheme.macroRingTier2Stroke,
                        color: tier2Color,
                        backgroundColor: Colors.transparent,
                        showGlow: false,
                      ),
                    // Center Text
                    Center(
                      child: Text(
                        percentText,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isOver ? displayExcessColor : color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLG),

          // Scaled Progress Bar
          LayoutBuilder(
            builder: (context, constraints) {
              // Total width represents max(Target, Current), so the goal mark
              // stays visible even when over.
              final double maxValue = progress > 1.0 ? progress : 1.0;
              final double goalPosition = 1.0 / maxValue;
              final double currentPosition = progress / maxValue;

              return Container(
                height: AppTheme.macroBarHeight,
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXXS),
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Base Content (Macro Color) — up to goal or current
                    FractionallySizedBox(
                      widthFactor:
                          progress > 1.0 ? goalPosition : currentPosition,
                      child: Container(
                        height: AppTheme.macroBarHeight,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.horizontal(
                            left:
                                const Radius.circular(AppTheme.macroBarRadius),
                            right: isOver
                                ? Radius.zero
                                : const Radius.circular(
                                    AppTheme.macroBarRadius,
                                  ),
                          ),
                        ),
                      ),
                    ),

                    // 2. Excess Content — from goal to current
                    if (isOver)
                      Padding(
                        padding: EdgeInsets.only(
                          left: constraints.maxWidth * goalPosition,
                        ),
                        child: Container(
                          height: AppTheme.macroBarHeight,
                          width: constraints.maxWidth *
                              (currentPosition - goalPosition),
                          decoration: BoxDecoration(
                            color: displayExcessColor,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(AppTheme.macroBarRadius),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    displayExcessColor.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // 3. Goal Marker Line — centered on the goal position
                    if (isOver)
                      Positioned(
                        left: constraints.maxWidth * goalPosition -
                            AppTheme.macroBarGoalMarkerWidth / 2,
                        child: Container(
                          width: AppTheme.macroBarGoalMarkerWidth,
                          height: AppTheme.macroBarHeight,
                          color: theme.colorScheme.surface,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: AppTheme.spaceMD),
          Wrap(
            spacing: AppTheme.spaceMD,
            runSpacing: AppTheme.spaceSM2,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                statusText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${remaining.abs().toStringAsFixed(1)} g',
                style: theme.textTheme.titleMedium?.copyWith(
                  color:
                      isOver ? displayExcessColor : theme.colorScheme.onSurface,
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
