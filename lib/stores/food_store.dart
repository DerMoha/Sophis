import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/nutrition_totals.dart';
import 'package:sophis/services/database_service.dart';

class FoodStore extends ChangeNotifier {
  final DatabaseService _db;

  List<FoodEntry> _entries = [];
  List<FoodItem> _recentFoods = [];
  DateTime? _cacheDate;

  FoodStore(this._db);

  List<FoodEntry> get entries => _entries;
  List<FoodItem> get recentFoods => _recentFoods;

  void loadData(List<FoodEntry> entries, List<FoodItem> recentFoods) {
    _entries = entries;
    _recentFoods = recentFoods;
    _invalidateCache();
    notifyListeners();
  }

  bool _isCacheValid() {
    if (_cacheDate == null) return false;
    final now = DateTime.now();
    return _cacheDate!.year == now.year &&
        _cacheDate!.month == now.month &&
        _cacheDate!.day == now.day;
  }

  void _prepareTodayCache() {
    if (_isCacheValid()) return;
    _cacheDate = DateTime.now();
  }

  void _invalidateCache() {
    _cacheDate = null;
  }

  Future<void> addFoodEntry(FoodEntry entry) async {
    _entries.add(entry);
    _invalidateCache();
    await _db.insertFood(entry);
    notifyListeners();
  }

  Future<void> removeFoodEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    _invalidateCache();
    await _db.deleteFood(id);
    notifyListeners();
  }

  Future<void> updateFoodEntry(FoodEntry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _entries[index] = entry;
      _invalidateCache();
      await _db.updateFood(entry);
      notifyListeners();
    }
  }

  Future<void> duplicateFoodEntry(FoodEntry entry, {String? toMeal}) {
    final newEntry = FoodEntry(
      id: const Uuid().v4(),
      name: entry.name,
      calories: entry.calories,
      protein: entry.protein,
      carbs: entry.carbs,
      fat: entry.fat,
      timestamp: DateTime.now(),
      meal: toMeal ?? entry.meal,
    );
    return addFoodEntry(newEntry);
  }

  List<FoodEntry> getTodayEntries() {
    _prepareTodayCache();
    final now = DateTime.now();
    return _entries
        .where(
          (e) =>
              e.timestamp.year == now.year &&
              e.timestamp.month == now.month &&
              e.timestamp.day == now.day,
        )
        .toList();
  }

  List<FoodEntry> getEntriesForDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return getTodayEntries();
    }
    return _entries.where((e) {
      return e.timestamp.year == date.year &&
          e.timestamp.month == date.month &&
          e.timestamp.day == date.day;
    }).toList();
  }

  List<FoodEntry> getEntriesByMeal(String meal) {
    final today = getTodayEntries();
    return today.where((e) => e.meal == meal).toList();
  }

  NutritionTotals getTodayTotals() {
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
    return totals;
  }

  NutritionTotals getTotalsForDate(DateTime date) {
    if (_isToday(date)) {
      return getTodayTotals();
    }
    final entries = getEntriesForDate(date);
    var totals = NutritionTotals.zero;
    for (final e in entries) {
      totals = totals +
          NutritionTotals(
            calories: e.calories,
            protein: e.protein,
            carbs: e.carbs,
            fat: e.fat,
          );
    }
    return totals;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Future<void> addRecentFood(FoodItem food) async {
    _recentFoods.removeWhere((f) => f.id == food.id);
    _recentFoods.insert(0, food);
    if (_recentFoods.length > 20) {
      _recentFoods = _recentFoods.take(20).toList();
    }
    notifyListeners();
  }

  void clearAll() {
    _entries = [];
    _recentFoods = [];
    _invalidateCache();
  }
}
