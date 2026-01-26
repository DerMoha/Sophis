import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../models/app_settings.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/animations.dart';
import '../../../../utils/unit_converter.dart';
import '../../../../widgets/organic_components.dart';
import '../../../../widgets/water_details_sheet.dart';
import '../../../../services/nutrition_provider.dart';

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
    final totalDisplay = UnitConverter.formatWater(waterTotal, unitSystem);
    final goalDisplay = UnitConverter.formatWater(waterGoal, unitSystem);

    return GlassCard(
      onTap: () => _showWaterDetails(context),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme, l10n, totalDisplay, goalDisplay),
          const SizedBox(height: 16),
          FluidProgressBar(value: progress, color: AppTheme.water, height: 10),
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
                borderRadius: BorderRadius.circular(10),
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

  Widget _buildButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: WaterDropButton(
            label: '+250ml',
            onPressed: () => context.read<NutritionProvider>().addWater(250),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: WaterDropButton(
            label: '+500ml',
            onPressed: () => context.read<NutritionProvider>().addWater(500),
          ),
        ),
      ],
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
