import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/settings_provider.dart';

/// Refreshes health-synced data (burned calories, weight) for the home screen.
Future<void> refreshBurnedCalories(BuildContext context) async {
  final settings = context.read<SettingsProvider>();
  final nutrition = context.read<NutritionProvider>();
  await nutrition.refreshBurnedCalories(enabled: settings.healthSyncEnabled);
  if (settings.healthWeightSyncEnabled) {
    await nutrition.syncWeightFromHealth();
  }
}
