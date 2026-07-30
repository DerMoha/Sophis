import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/app_settings.dart';
import 'package:sophis/models/water_entry.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/utils/time_utils.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/theme/animations.dart';
import 'package:sophis/utils/unit_converter.dart';
import 'package:sophis/ui/components/organic_components.dart';

class WaterScreen extends StatefulWidget {
  const WaterScreen({super.key});

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _addCustomWater() {
    final amount = double.tryParse(_customController.text);
    if (amount == null || amount <= 0) return;

    // Convert from display unit to ml for storage
    final unitSystem = context.read<SettingsProvider>().unitSystem;
    final amountMl = UnitConverter.inputToMl(amount, unitSystem);

    context.read<NutritionProvider>().addWater(amountMl);
    _customController.clear();
    FocusScope.of(context).unfocus();
  }

  void _deleteEntry(String id) {
    context.read<NutritionProvider>().removeWaterEntry(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.water),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: AppTheme.pagePadding,
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Quick add buttons
                FadeInSlide(
                  index: 0,
                  child: Consumer<SettingsProvider>(
                    builder: (context, settings, _) {
                      final sizes = settings.waterSizes;
                      final unitSystem = settings.unitSystem;
                      return GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.add,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _QuickAddButton(
                                  amountMl: sizes[0],
                                  unitSystem: unitSystem,
                                  icon: Icons.local_cafe_outlined,
                                  onTap: () {
                                    context
                                        .read<NutritionProvider>()
                                        .addWater(sizes[0].toDouble());
                                  },
                                ),
                                _QuickAddButton(
                                  amountMl: sizes[1],
                                  unitSystem: unitSystem,
                                  icon: Icons.coffee_outlined,
                                  onTap: () {
                                    context
                                        .read<NutritionProvider>()
                                        .addWater(sizes[1].toDouble());
                                  },
                                ),
                                _QuickAddButton(
                                  amountMl: sizes[2],
                                  unitSystem: unitSystem,
                                  icon: Icons.water_drop_outlined,
                                  onTap: () {
                                    context
                                        .read<NutritionProvider>()
                                        .addWater(sizes[2].toDouble());
                                  },
                                ),
                                _QuickAddButton(
                                  amountMl: sizes[3],
                                  unitSystem: unitSystem,
                                  icon: Icons.local_drink_outlined,
                                  onTap: () {
                                    context
                                        .read<NutritionProvider>()
                                        .addWater(sizes[3].toDouble());
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLG2),

                // Custom Entry
                FadeInSlide(
                  index: 1,
                  child: Consumer<SettingsProvider>(
                    builder: (context, settings, _) {
                      final unitSystem = settings.unitSystem;
                      final waterUnit =
                          UnitConverter.waterUnitShort(unitSystem);
                      final largeText =
                          MediaQuery.textScalerOf(context).scale(1) > 1.3;
                      return OrganicCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.water,
                                        AppTheme.water.withValues(alpha: 0.7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMD,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.add,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            largeText
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      TextField(
                                        controller: _customController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          hintText: waterUnit,
                                          prefixIcon: const Icon(
                                            Icons.water_drop_outlined,
                                            size: 20,
                                          ),
                                        ),
                                        onSubmitted: (_) => _addCustomWater(),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 52,
                                        child: ElevatedButton(
                                          onPressed: _addCustomWater,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.water,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: Text(l10n.add),
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _customController,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            hintText: waterUnit,
                                            prefixIcon: const Icon(
                                              Icons.water_drop_outlined,
                                              size: 20,
                                            ),
                                          ),
                                          onSubmitted: (_) => _addCustomWater(),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        height: 52,
                                        child: ElevatedButton(
                                          onPressed: _addCustomWater,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.water,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                            ),
                                          ),
                                          child: Text(l10n.add),
                                        ),
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // History List
                FadeInSlide(
                  index: 2,
                  child: SectionHeader(
                    title: l10n.today,
                    icon: Icons.history_outlined,
                  ),
                ),

                Selector<NutritionProvider, List<WaterEntry>>(
                  selector: (_, n) => n.getTodayWaterEntries(),
                  builder: (context, entries, _) {
                    final unitSystem =
                        context.select<SettingsProvider, UnitSystem>(
                      (s) => s.unitSystem,
                    );

                    if (entries.isEmpty) {
                      return FadeInSlide(
                        index: 3,
                        child: EmptyState(
                          icon: Icons.water_drop_outlined,
                          title: l10n.noEntries,
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return FadeInSlide(
                          index: 3 + index,
                          delay: const Duration(milliseconds: 30),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMD),
                              border: Border.all(
                                color: theme.brightness == Brightness.dark
                                    ? CachedColors.surfaceTintDark06
                                    : CachedColors.surfaceTintLight04,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.water.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSM,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.water_drop,
                                    color: AppTheme.water,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        UnitConverter.formatWaterShort(
                                          entry.amountMl,
                                          unitSystem,
                                        ),
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
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
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  final int amountMl;
  final UnitSystem unitSystem;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickAddButton({
    required this.amountMl,
    required this.unitSystem,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayText =
        UnitConverter.formatWaterShort(amountMl.toDouble(), unitSystem);

    return SizedBox(
      width: 104,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.water.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(
                color: AppTheme.water.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: AppTheme.water,
                  size: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  displayText,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.water,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
