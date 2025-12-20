import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/nutrition_provider.dart';
import '../theme/app_theme.dart';


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

    context.read<NutritionProvider>().addWater(amount);
    _customController.clear();
    Navigator.pop(context); // Close sheet after adding
  }

  void _deleteEntry(String id) {
    context.read<NutritionProvider>().removeWaterEntry(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Water Log',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppTheme.water,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Custom Entry
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Custom Amount (ml)',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addCustomWater(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _addCustomWater,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.water,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // History List
          Text(
            'Today\'s History',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          
          Flexible(
            child: Consumer<NutritionProvider>(
              builder: (context, nutrition, _) {
                final entries = nutrition.getTodayWaterEntries();
                
                if (entries.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No water logged yet today',
                        style: TextStyle(color: theme.disabledColor),
                      ),
                    ),
                  );
                }
                
                return SizedBox(
                  height: 300, // Limit height
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.water_drop, color: AppTheme.water, size: 20),
                        title: Text(
                          '${entry.amountMl.toStringAsFixed(0)} ml',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(_formatTime(entry.timestamp)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                          onPressed: () => _deleteEntry(entry.id),
                          tooltip: 'Remove',
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
