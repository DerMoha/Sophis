import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/app_settings.dart';
import 'package:sophis/services/settings_provider.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/theme/animations.dart';
import 'package:sophis/utils/unit_converter.dart';
import 'package:sophis/ui/components/organic_components.dart';
import 'package:sophis/ui/components/water_details_sheet.dart';
import 'package:sophis/services/nutrition_provider.dart';

/// Water tracking card for the modern home screen.
class WaterCard extends StatelessWidget {
  final double waterTotal;
  final double waterGoal;
  final UnitSystem unitSystem;

  const WaterCard({
    super.key,
    required this.waterTotal,
    required this.waterGoal,
    required this.unitSystem,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final progress = (waterTotal / waterGoal).clamp(0.0, 1.0);
    final remainingWater = (waterGoal - waterTotal).clamp(0.0, double.infinity);
    final totalDisplay = UnitConverter.formatWater(waterTotal, unitSystem);
    final goalDisplay = UnitConverter.formatWater(waterGoal, unitSystem);
    final remainingDisplay = UnitConverter.formatWaterShort(
      remainingWater,
      unitSystem,
    );
    final helperText =
        progress >= 1 ? l10n.allDone : '$remainingDisplay ${l10n.remaining}';

    return GlassCard(
      onTap: () => _showWaterDetails(context),
      padding: const EdgeInsets.all(AppTheme.spaceLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme, l10n, totalDisplay, goalDisplay),
          const SizedBox(height: 16),
          FluidProgressBar(value: progress, color: AppTheme.water, height: 10),
          const SizedBox(height: 10),
          _buildProgressMeta(theme, progress, helperText),
          const SizedBox(height: 16),
          _buildButtons(context),
        ],
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    AppLocalizations l10n,
    String totalDisplay,
    String goalDisplay,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.water.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: const Icon(
                Icons.water_drop_rounded,
                color: AppTheme.water,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(l10n.water, style: theme.textTheme.titleMedium),
          ],
        ),
        Text(
          '$totalDisplay / $goalDisplay',
          style: theme.textTheme.titleSmall?.copyWith(
            color: AppTheme.water,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressMeta(
    ThemeData theme,
    double progress,
    String helperText,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.water.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
          child: Text(
            '${(progress * 100).round()}%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.water,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            helperText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    final quickAddSizes = context.select<SettingsProvider, List<int>>(
      (settings) => settings.waterSizes,
    );

    return Row(
      children: quickAddSizes.take(2).map((amountMl) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: amountMl == quickAddSizes.first ? AppTheme.spaceSM : 0,
            ),
            child: WaterDropButton(
              label:
                  '+${UnitConverter.formatWaterShort(amountMl.toDouble(), unitSystem)}',
              onPressed: () => context
                  .read<NutritionProvider>()
                  .addWater(amountMl.toDouble()),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showWaterDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WaterDetailsSheet(),
    );
  }
}
