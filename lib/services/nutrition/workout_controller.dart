import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../models/workout_entry.dart';
import '../database_service.dart';
import '../home_widget_service.dart';
import '../nutrition_provider.dart';

/// Manages workout entries and today's workout cache.
class WorkoutController {
  final DatabaseService _db;
  final VoidCallback _onChanged;
  final bool Function() _isCacheValid;
  final DateTime Function() _currentCacheDate;
  final NutritionProvider Function() _providerRef;

  List<WorkoutEntry> _workoutEntries = [];

  double? _cachedTodayWorkoutCalories;
  List<WorkoutEntry>? _cachedTodayWorkoutEntries;

  WorkoutController(
    this._db,
    this._onChanged,
    this._isCacheValid,
    this._currentCacheDate,
    this._providerRef,
  );

  List<WorkoutEntry> get workoutEntries => _workoutEntries;

  void loadData(List<WorkoutEntry> entries) {
    _workoutEntries = entries;
    invalidateCache();
  }

  void invalidateCache() {
    _cachedTodayWorkoutCalories = null;
    _cachedTodayWorkoutEntries = null;
  }

  void _prepareTodayCache() {
    if (_isCacheValid()) return;
    invalidateCache();
  }

  Future<void> addWorkoutEntry(double calories, {String? note}) async {
    final entry = WorkoutEntry(
      id: const Uuid().v4(),
      caloriesBurned: calories,
      timestamp: DateTime.now(),
      note: note,
    );
    await restoreWorkoutEntry(entry);
  }

  Future<void> restoreWorkoutEntry(WorkoutEntry entry) async {
    _workoutEntries.add(entry);
    invalidateCache();
    await _db.insertWorkout(entry);
    HomeWidgetService.updateWidgetData(_providerRef());
    _onChanged();
  }

  Future<void> updateWorkoutEntry(WorkoutEntry entry) async {
    final index = _workoutEntries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _workoutEntries[index] = entry;
      invalidateCache();
      await _db.updateWorkout(entry);
      HomeWidgetService.updateWidgetData(_providerRef());
      _onChanged();
    }
  }

  Future<void> removeWorkoutEntry(String id) async {
    _workoutEntries.removeWhere((e) => e.id == id);
    invalidateCache();
    await _db.deleteWorkout(id);
    HomeWidgetService.updateWidgetData(_providerRef());
    _onChanged();
  }

  double getTodayWorkoutCalories() {
    _prepareTodayCache();
    if (_cachedTodayWorkoutCalories != null) {
      return _cachedTodayWorkoutCalories!;
    }

    final now = _currentCacheDate();
    var total = 0.0;
    final todayEntries = <WorkoutEntry>[];

    for (final entry in _workoutEntries) {
      if (entry.timestamp.year == now.year &&
          entry.timestamp.month == now.month &&
          entry.timestamp.day == now.day) {
        total += entry.caloriesBurned;
        todayEntries.add(entry);
      }
    }

    todayEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _cachedTodayWorkoutCalories = total;
    _cachedTodayWorkoutEntries = todayEntries;
    return total;
  }

  List<WorkoutEntry> getTodayWorkoutEntries() {
    _prepareTodayCache();
    if (_cachedTodayWorkoutEntries != null) {
      return _cachedTodayWorkoutEntries!;
    }
    getTodayWorkoutCalories();
    return _cachedTodayWorkoutEntries ?? const <WorkoutEntry>[];
  }

  void clearAll() {
    _workoutEntries = [];
    invalidateCache();
  }
}
