import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../../services/nutrition_provider.dart';
import '../../../services/settings_provider.dart';

/// Refreshes burned calories from health data.
/// Used by both modern and legacy home screens.
Future<void> refreshBurnedCalories(BuildContext context) async {
  final settings = context.read<SettingsProvider>();
  final nutrition = context.read<NutritionProvider>();
  await nutrition.refreshBurnedCalories(enabled: settings.healthSyncEnabled);
}
