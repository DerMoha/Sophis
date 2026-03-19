import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../models/food_entry.dart';
import '../../models/food_item.dart';
import '../../models/nutrition_totals.dart';
import '../database_service.dart';

/// Manages food entries, today's cache, and food history cache.
class FoodLogController {
  final DatabaseService _db;
  final VoidCallback _onChanged;
  final bool Function() _isCacheValid;
  final DateTime Function() _currentCacheDate;

  List<FoodEntry> _entries = [];
  List<FoodItem> _recentFoods = [];

  // Today's cache
  List<FoodEntry>? _cachedTodayEntries;
  NutritionTotals? _cachedTodayTotals;
  Map<String, List<FoodEntry>>? _cachedMealEntries;

  // History cache
  Map<int, List<FoodEntry>>? _foodEntriesByDateCache;
  Map<int, NutritionTotals>? _foodTotalsByDateCache;

  FoodLogController(
    this._db,
    this._onChanged,
    this._isCacheValid,
    this._currentCacheDate,
  );

  List<FoodEntry> get entries => _entries;
  List<FoodItem> get recentFoods => _recentFoods;

  void loadData(
    List<FoodEntry> entries,
    List<FoodItem> recentFoods,
  ) {
    _entries = entries;
    _recentFoods = recentFoods;
    invalidateCache();
    invalidateFoodHistoryCache();
  }

  void invalidateCache() {
    _cachedTodayEntries = null;
    _cachedTodayTotals = null;
    _cachedMealEntries = null;
  }

  void invalidateFoodHistoryCache() {
    _foodEntriesByDateCache = null;
    _foodTotalsByDateCache = null;
  }

  void _prepareTodayCache() {
    if (_isCacheValid()) return;
    invalidateCache();
  }

  int _dayKey(DateTime date) => date.year * 10000 + date.month * 100 + date.day;

  void _ensureFoodHistoryCache() {
    if (_foodEntriesByDateCache != null && _foodTotalsByDateCache != null) {
      return;
    }

    final entriesByDate = <int, List<FoodEntry>>{};
    final totalsByDate = <int, NutritionTotals>{};

    for (final entry in _entries) {
      final key = _dayKey(entry.timestamp);
      entriesByDate.putIfAbsent(key, () => []).add(entry);

      final existing = totalsByDate[key] ?? NutritionTotals.zero;
      totalsByDate[key] = existing +
          NutritionTotals(
            calories: entry.calories,
            protein: entry.protein,
            carbs: entry.carbs,
            fat: entry.fat,
          );
    }

    _foodEntriesByDateCache = {
      for (final item in entriesByDate.entries)
        item.key: List<FoodEntry>.unmodifiable(item.value),
    };
    _foodTotalsByDateCache = totalsByDate;
  }

  Future<void> addFoodEntry(FoodEntry entry) async {
    _entries.add(entry);
    invalidateCache();
    invalidateFoodHistoryCache();
    await _db.insertFood(entry);
    _onChanged();
  }

  Future<void> removeFoodEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    invalidateCache();
    invalidateFoodHistoryCache();
    await _db.deleteFood(id);
    _onChanged();
  }

  Future<void> updateFoodEntry(FoodEntry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _entries[index] = entry;
      invalidateCache();
      invalidateFoodHistoryCache();
      await _db.updateFood(entry);
      _onChanged();
    }
  }

  Future<void> duplicateFoodEntry(FoodEntry entry, {String? toMeal}) async {
    final newEntry = entry.copyWith(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      meal: toMeal ?? entry.meal,
    );
    await addFoodEntry(newEntry);
  }

  List<FoodEntry> getTodayEntries() {
    _prepareTodayCache();

    if (_cachedTodayEntries != null) {
      return _cachedTodayEntries!;
    }

    final now = _currentCacheDate();
    _cachedTodayEntries = _entries
        .where(
          (e) =>
              e.timestamp.year == now.year &&
              e.timestamp.month == now.month &&
              e.timestamp.day == now.day,
        )
        .toList();

    _cachedMealEntries = {};
    for (final entry in _cachedTodayEntries!) {
      _cachedMealEntries!.putIfAbsent(entry.meal, () => []).add(entry);
    }

    return _cachedTodayEntries!;
  }

  List<FoodEntry> getEntriesForDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return getTodayEntries();
    }

    _ensureFoodHistoryCache();
    return _foodEntriesByDateCache![_dayKey(date)] ?? const <FoodEntry>[];
  }

  List<FoodEntry> getEntriesByMeal(String meal) {
    getTodayEntries();

    if (_cachedMealEntries != null && _cachedMealEntries!.containsKey(meal)) {
      return _cachedMealEntries![meal]!;
    }
    return [];
  }

  /// Returns today's nutrition totals (typed).
  NutritionTotals getTodayTotalsTyped() {
    _prepareTodayCache();

    if (_cachedTodayTotals != null) {
      return _cachedTodayTotals!;
    }

    final today = getTodayEntries();
    var totals = NutritionTotals.zero;
    for (final e in today) {
      totals = totals +
          NutritionTotals(
            calories: e.calories,
            protein: e.protein,
            carbs: e.carbs,
            fat: e.fat,
          );
    }
    _cachedTodayTotals = totals;
    return totals;
  }

  /// Returns today's nutrition totals.
  NutritionTotals getTodayTotals() => getTodayTotalsTyped();

  /// Returns nutrition totals for a specific date (typed).
  NutritionTotals getTotalsForDateTyped(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return getTodayTotalsTyped();
    }

    _ensureFoodHistoryCache();
    return _foodTotalsByDateCache![_dayKey(date)] ?? NutritionTotals.zero;
  }

  /// Returns nutrition totals for a specific date.
  NutritionTotals getTotalsForDate(DateTime date) =>
      getTotalsForDateTyped(date);

  Future<void> addRecentFood(FoodItem food) async {
    _recentFoods.removeWhere((f) => f.id == food.id);
    _recentFoods.insert(0, food);
    if (_recentFoods.length > 20) {
      _recentFoods = _recentFoods.take(20).toList();
    }
    _onChanged();
  }

  void clearAll() {
    _entries = [];
    _recentFoods = [];
    invalidateCache();
    invalidateFoodHistoryCache();
  }
}
