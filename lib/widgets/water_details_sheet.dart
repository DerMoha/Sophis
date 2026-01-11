import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../services/nutrition_provider.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../utils/unit_converter.dart';
import '../l10n/generated/app_localizations.dart';

class WaterDetailsSheet extends StatefulWidget {
  const WaterDetailsSheet({super.key});

  @override
  State<WaterDetailsSheet> createState() => _WaterDetailsSheetState();
}

class _WaterDetailsSheetState extends State<WaterDetailsSheet> {
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
    Navigator.pop(context);
  }

  void _deleteEntry(String id) {
    context.read<NutritionProvider>().removeWaterEntry(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.water.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.water_drop_rounded,
                        color: AppTheme.water,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.water,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ],
                ),
                IconButton(
                  icon: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close, size: 18),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick add buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Consumer<SettingsProvider>(
              builder: (context, settings, _) {
                final sizes = settings.waterSizes;
                final unitSystem = settings.unitSystem;
                return Row(
                  children: [
                    _QuickAddButton(
                      amountMl: sizes[0],
                      unitSystem: unitSystem,
                      icon: Icons.local_cafe_outlined,
                      onTap: () {
                        context.read<NutritionProvider>().addWater(sizes[0].toDouble());
                      },
                    ),
                    const SizedBox(width: 12),
                    _QuickAddButton(
                      amountMl: sizes[1],
                      unitSystem: unitSystem,
                      icon: Icons.coffee_outlined,
                      onTap: () {
                        context.read<NutritionProvider>().addWater(sizes[1].toDouble());
                      },
                    ),
                    const SizedBox(width: 12),
                    _QuickAddButton(
                      amountMl: sizes[2],
                      unitSystem: unitSystem,
                      icon: Icons.water_drop_outlined,
                      onTap: () {
                        context.read<NutritionProvider>().addWater(sizes[2].toDouble());
                      },
                    ),
                    const SizedBox(width: 12),
                    _QuickAddButton(
                      amountMl: sizes[3],
                      unitSystem: unitSystem,
                      icon: Icons.local_drink_outlined,
                      onTap: () {
                        context.read<NutritionProvider>().addWater(sizes[3].toDouble());
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Custom Entry
          Consumer<SettingsProvider>(
            builder: (context, settings, _) {
              final unitSystem = settings.unitSystem;
              final waterUnit = UnitConverter.waterUnitShort(unitSystem);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: waterUnit,
                          prefixIcon: const Icon(Icons.edit_outlined, size: 20),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
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
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        child: Text(l10n.add),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // History List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  l10n.today,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Flexible(
            child: Consumer2<NutritionProvider, SettingsProvider>(
              builder: (context, nutrition, settings, _) {
                final entries = nutrition.getTodayWaterEntries();
                final unitSystem = settings.unitSystem;

                if (entries.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppTheme.water.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.water_drop_outlined,
                            color: AppTheme.water.withOpacity(0.5),
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.noEntries,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return SizedBox(
                  height: 280,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return FadeInSlide(
                        index: index,
                        delay: const Duration(milliseconds: 30),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.02),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppTheme.water.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.water_drop,
                                  color: AppTheme.water,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      UnitConverter.formatWaterShort(entry.amountMl, unitSystem),
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      _formatTime(entry.timestamp),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: AppTheme.error.withOpacity(0.7),
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
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour =
        time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
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
    final displayText = UnitConverter.formatWaterShort(amountMl.toDouble(), unitSystem);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.water.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(
                color: AppTheme.water.withOpacity(0.15),
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
