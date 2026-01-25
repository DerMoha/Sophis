import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart';
import '../services/nutrition_provider.dart';
import 'log_service.dart';

class HomeWidgetService {
  static const String appGroupId = 'group.sophis.sophis';
  static const String iOSWidgetName = 'SophisWidget';
  static const String androidWidgetName = 'SophisWidgetProvider';

  static Future<void> updateWidgetData(NutritionProvider provider) async {
    try {
      final totals = provider.getTodayTotals();
      final remaining = provider.getRemainingCalories();
      final water = provider.getTodayWaterTotal();
      final goal = provider.goals?.calories ?? 0;

      Log.debug('Updating widget: cal=${totals['calories']?.toInt()}/$goal, protein=${totals['protein']?.toInt()}g');

      // Save data
      await HomeWidget.saveWidgetData<double>(
          'calories_eaten', totals['calories']);
      await HomeWidget.saveWidgetData<double>(
          'calories_goal', goal);
      await HomeWidget.saveWidgetData<double>('calories_remaining', remaining);

      // Save Macro Totals
      await HomeWidget.saveWidgetData<double>(
          'protein_eaten', totals['protein']);
      await HomeWidget.saveWidgetData<double>('carbs_eaten', totals['carbs']);
      await HomeWidget.saveWidgetData<double>('fat_eaten', totals['fat']);

      // Save Macro Goals
      await HomeWidget.saveWidgetData<double>(
          'protein_goal', provider.goals?.protein ?? 150); // Default fallback
      await HomeWidget.saveWidgetData<double>(
          'carbs_goal', provider.goals?.carbs ?? 200);
      await HomeWidget.saveWidgetData<double>(
          'fat_goal', provider.goals?.fat ?? 60);

      await HomeWidget.saveWidgetData<double>('water_ml', water);
      await HomeWidget.saveWidgetData<double>(
          'water_goal', 2500.0); // Default water goal

      // Trigger update
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        iOSName: iOSWidgetName,
      );

      Log.info('Widget sync completed');
    } catch (e, stackTrace) {
      Log.error('Widget sync failed', error: e, stackTrace: stackTrace);
    }
  }
}
