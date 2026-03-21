import 'dart:async';

import 'package:home_widget/home_widget.dart';

import '../services/nutrition_provider.dart';

class HomeWidgetService {
  static const String appGroupId = 'group.sophis.sophis';
  static const String iOSWidgetName = 'SophisWidget';
  static const String androidWidgetName = 'SophisWidgetProvider';
  static const Duration _widgetSyncDebounce = Duration(milliseconds: 350);

  static Timer? _widgetSyncTimer;
  static NutritionProvider? _pendingProvider;
  static bool _isSyncing = false;
  static bool _hasPendingSync = false;

  static Future<void> updateWidgetData(NutritionProvider provider) {
    _pendingProvider = provider;
    _hasPendingSync = true;

    _widgetSyncTimer?.cancel();
    _widgetSyncTimer = Timer(_widgetSyncDebounce, () {
      unawaited(_flushPendingSync());
    });

    return Future.value();
  }

  static Future<void> _flushPendingSync() async {
    if (_isSyncing || !_hasPendingSync) return;
    final provider = _pendingProvider;
    if (provider == null) return;

    _isSyncing = true;
    _hasPendingSync = false;

    try {
      await _writeWidgetData(provider);
    } finally {
      _isSyncing = false;
      if (_hasPendingSync) {
        _widgetSyncTimer?.cancel();
        _widgetSyncTimer = Timer(_widgetSyncDebounce, () {
          unawaited(_flushPendingSync());
        });
      }
    }
  }

  static Future<void> _writeWidgetData(NutritionProvider provider) async {
    try {
      final totals = provider.getTodayTotals();
      final remaining = provider.getRemainingCalories();
      final water = provider.getTodayWaterTotal();
      final goal = provider.goals?.calories ?? 0;

      // Save data
      await HomeWidget.saveWidgetData<double>(
        'calories_eaten',
        totals.calories,
      );
      await HomeWidget.saveWidgetData<double>('calories_goal', goal);
      await HomeWidget.saveWidgetData<double>('calories_remaining', remaining);

      // Save Macro Totals
      await HomeWidget.saveWidgetData<double>(
        'protein_eaten',
        totals.protein,
      );
      await HomeWidget.saveWidgetData<double>('carbs_eaten', totals.carbs);
      await HomeWidget.saveWidgetData<double>('fat_eaten', totals.fat);

      // Save Macro Goals
      await HomeWidget.saveWidgetData<double>(
        'protein_goal',
        provider.goals?.protein ?? 150,
      ); // Default fallback
      await HomeWidget.saveWidgetData<double>(
        'carbs_goal',
        provider.goals?.carbs ?? 200,
      );
      await HomeWidget.saveWidgetData<double>(
        'fat_goal',
        provider.goals?.fat ?? 60,
      );

      await HomeWidget.saveWidgetData<double>('water_ml', water);
      await HomeWidget.saveWidgetData<double>(
        'water_goal',
        2500.0,
      ); // Default water goal

      // Trigger update
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        iOSName: iOSWidgetName,
      );
    } catch (e) {
      // Widget sync failed silently
    }
  }
}
