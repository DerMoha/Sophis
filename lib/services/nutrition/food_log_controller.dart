import 'package:uuid/uuid.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/meal_template.dart';
import 'package:sophis/models/nutrition_totals.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/models/portion_selection.dart';
import 'package:sophis/services/database_service.dart';
import 'package:sophis/services/nutrition/nutrition_store.dart';

/// Manages food entries, today's cache, and food history cache.
class FoodLogController {
  final DatabaseService _db;
  final Future<void> Function() _onChanged;
  final bool Function() _isCacheValid;
  final DateTime Function() _currentCacheDate;
  final NutritionStore? _store;

  List<FoodEntry> _entries = [];
  List<FoodItem> _recentFoods = [];
  final Map<String, String> _recentFoodMeals = {};

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
    this._currentCacheDate, {
    NutritionStore? store,
  }) : _store = store;

  List<FoodEntry> get entries => _entries;
  List<FoodItem> get recentFoods => _recentFoods;

  /// Returns the safest portion to use for a one-tap recent-food action.
  ///
  /// A remembered portion wins only when its unit still matches the food's
  /// nutrition basis. Otherwise we use the item's one-serving option, or the
  /// explicit 100-unit fallback. The fallback is deliberately expressed in
  /// the food's canonical unit, never as an implicit gram conversion.
  static PortionSelection defaultPortionFor(FoodItem food) {
    final remembered = food.lastUsedPortion;
    if (remembered != null &&
        remembered.unit == food.nutritionUnit &&
        remembered.isValid) {
      return remembered;
    }

    final matchingServings = food.servings
        .where((serving) => serving.unit == food.nutritionUnit)
        .toList();
    for (final serving in matchingServings) {
      if ((serving.multiplier - 1.0).abs() < 0.001 &&
          serving.selection.isValid) {
        return serving.selection;
      }
    }
    if (matchingServings.isNotEmpty &&
        matchingServings.first.selection.isValid) {
      return matchingServings.first.selection;
    }

    return PortionSelection(amount: 100, unit: food.nutritionUnit);
  }

  FoodItem? getRecentFoodById(String id) {
    for (final food in _recentFoods) {
      if (food.id == id) return food;
    }
    return null;
  }

  void loadData(
    List<FoodEntry> entries,
    List<FoodItem> recentFoods,
    Map<String, String>? recentFoodMeals,
  ) {
    _entries = entries;
    _recentFoods = recentFoods;
    _recentFoodMeals
      ..clear()
      ..addAll(recentFoodMeals ?? const {});
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
            fiber: entry.fiber,
          );
    }

    _foodEntriesByDateCache = {
      for (final item in entriesByDate.entries)
        item.key: List<FoodEntry>.unmodifiable(item.value),
    };
    _foodTotalsByDateCache = totalsByDate;
  }

  Future<void> addFoodEntry(FoodEntry entry) async {
    if (_store == null) {
      await _db.insertFood(entry);
    } else {
      await _store!.commitOrThrow(SaveFoodEntry(entry));
    }
    _entries.add(entry);
    invalidateCache();
    invalidateFoodHistoryCache();
    await _onChanged();
  }

  Future<void> removeFoodEntry(String id) async {
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index == -1) return;

    if (_store == null) {
      await _db.deleteFood(id);
    } else {
      await _store!.commitOrThrow(DeleteFoodEntry(id));
    }
    _entries.removeAt(index);
    invalidateCache();
    invalidateFoodHistoryCache();
    await _onChanged();
  }

  Future<void> updateFoodEntry(FoodEntry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      if (_store == null) {
        final updated = await _db.updateFood(entry);
        if (!updated) return;
      } else {
        await _store!.commitOrThrow(SaveFoodEntry(entry));
      }

      _entries[index] = entry;
      invalidateCache();
      invalidateFoodHistoryCache();
      await _onChanged();
    }
  }

  Future<void> duplicateFoodEntry(FoodEntry entry, {String? toMeal}) async {
    final newEntry = entry.copyWith(meal: toMeal ?? entry.meal);
    await _addClonedEntries(
      [newEntry],
      timestamps: [DateTime.now()],
    );
  }

  /// Returns the entries that make up the most recently logged meal.
  ///
  /// The latest entry identifies the meal instance. Entries from the same
  /// meal and calendar day are copied together, so a multi-item breakfast is
  /// repeated as one action instead of repeating only its final item.
  List<FoodEntry> getLastLoggedMealEntries({String? meal}) {
    final candidates = meal == null ? _entries : _entries.where((entry) => entry.meal == meal).toList();
    if (candidates.isEmpty) return const <FoodEntry>[];

    final latestEntry = candidates.reduce(
      (current, candidate) =>
          candidate.timestamp.isAfter(current.timestamp) ? candidate : current,
    );
    final matching = _entries
        .where(
          (entry) =>
              entry.meal == latestEntry.meal &&
              _sameCalendarDate(entry.timestamp, latestEntry.timestamp),
        )
        .toList();
    matching.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return matching;
  }

  /// Repeats the most recently logged meal at [timestamp].
  Future<List<FoodEntry>> repeatLastMeal({DateTime? timestamp, String? meal}) async {
    final source = getLastLoggedMealEntries(meal: meal);
    return repeatEntries(source, timestamp: timestamp);
  }

  Future<List<FoodEntry>> repeatEntries(List<FoodEntry> source, {DateTime? timestamp}) async {
    if (source.isEmpty) return const <FoodEntry>[];
    final start = timestamp ?? DateTime.now();
    final timestamps = [
      for (var index = 0; index < source.length; index++)
        start.add(Duration(milliseconds: index)),
    ];
    return _addClonedEntries(source, timestamps: timestamps);
  }

  /// Copies all logged meals from the day before [targetDate] to that date.
  ///
  /// The time of day, meal type, nutrition snapshot, and portion metadata are
  /// retained. Only the entry IDs and calendar date change.
  Future<List<FoodEntry>> copyYesterdayLoggedMeals({
    DateTime? targetDate,
  }) async {
    final target = targetDate ?? DateTime.now();
    final targetDay = DateTime(target.year, target.month, target.day);
    final sourceDay = targetDay.subtract(const Duration(days: 1));
    final source = getEntriesForDate(sourceDay);
    if (source.isEmpty) return const <FoodEntry>[];

    final timestamps = [
      for (final entry in source)
        targetDay.add(entry.timestamp.difference(sourceDay)),
    ];
    return _addClonedEntries(source, timestamps: timestamps);
  }

  /// Logs every item in a saved meal template from its stored food snapshot.
  Future<List<FoodEntry>> logMealTemplate(
    MealTemplate template, {
    DateTime? timestamp,
  }) async {
    final start = timestamp ?? DateTime.now();
    final entries = <FoodEntry>[];

    for (var index = 0; index < template.items.length; index++) {
      final templateItem = template.items[index];
      final selection = templateItem.selection;
      if (!selection.isValid) {
        throw ArgumentError.value(
          selection.amount,
          'template.items[$index].selection.amount',
          'A template portion must be greater than zero',
        );
      }

      final nutrients =
          templateItem.food.calculateForSelection(templateItem.selection);
      final displayName =
          templateItem.food.brand != null && templateItem.food.brand!.isNotEmpty
              ? '${templateItem.food.brand} ${templateItem.food.name}'
              : templateItem.food.name;
      entries.add(
        FoodEntry(
          id: const Uuid().v4(),
          name: '$displayName (${_formatSelection(selection)})',
          calories: nutrients.calories,
          protein: nutrients.protein,
          carbs: nutrients.carbs,
          fat: nutrients.fat,
          fiber: nutrients.fiber,
          timestamp: start.add(Duration(milliseconds: index)),
          meal: templateItem.meal,
          sourceFoodId: templateItem.food.id,
          portionAmount: selection.amount,
          portionUnit: selection.unit,
          portionLabel: selection.humanLabel,
          portionQuantity: selection.labelQuantity,
        ),
      );
    }

    return _addPreparedEntries(entries);
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
            fiber: e.fiber,
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

  List<FoodItem> getRecentFoodsForMeal(String meal) {
    final matching = {for (final food in _recentFoods)
      if (_recentFoodMeals[food.id] == meal) food.id: food,};
    // Recover older scanned foods from their logged nutrition snapshots too,
    // so extending the cache helps existing breakfast histories immediately.
    final history = _entries.where((entry) => entry.meal == meal && entry.sourceFoodId != null).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    for (final entry in history) {
      final id = entry.sourceFoodId!;
      final selection = entry.portionSelection;
      if (matching.containsKey(id) || selection == null || !selection.isValid) continue;
      final suffix = ' (${entry.displayPortionText})';
      final name = entry.name.endsWith(suffix) ? entry.name.substring(0, entry.name.length - suffix.length) : entry.name;
      final factor = 100 / selection.amount;
      matching[id] = FoodItem(
        id: id, name: name, category: 'history',
        caloriesPer100g: entry.calories * factor, proteinPer100g: entry.protein * factor,
        carbsPer100g: entry.carbs * factor, fatPer100g: entry.fat * factor,
        fiberPer100g: entry.fiber * factor, nutritionUnit: selection.unit,
        lastUsedPortion: selection,
      );
      if (matching.length >= 100) break;
    }
    return matching.isNotEmpty ? matching.values.take(100).toList() : _recentFoods;
  }

  Future<void> addRecentFood(FoodItem food, {String? meal}) async {
    final previousFoods = List<FoodItem>.of(_recentFoods);
    final previousMeals = Map<String, String>.of(_recentFoodMeals);

    _recentFoods.removeWhere((f) => f.id == food.id);
    _recentFoods.insert(0, food);
    if (meal != null) {
      _recentFoodMeals[food.id] = meal;
    }
    if (_recentFoods.length > 100) {
      _recentFoods = _recentFoods.take(100).toList();
    }

    try {
      await _onChanged();
    } catch (_) {
      _recentFoods = previousFoods;
      _recentFoodMeals
        ..clear()
        ..addAll(previousMeals);
      rethrow;
    }
  }

  Map<String, String> get recentFoodMeals =>
      Map<String, String>.unmodifiable(_recentFoodMeals);

  Future<void> rememberRecentPortion(
    FoodItem food,
    PortionSelection selection, {
    String? meal,
  }) async {
    if (!selection.isValid) {
      throw ArgumentError.value(
        selection.amount,
        'selection.amount',
        'A remembered portion must be greater than zero',
      );
    }
    if (selection.unit != food.nutritionUnit) {
      throw ArgumentError.value(
        selection.unit,
        'selection.unit',
        'A remembered portion must use the food nutrition unit',
      );
    }
    await addRecentFood(
      food.copyWith(lastUsedPortion: selection),
      meal: meal,
    );
  }

  void clearAll() {
    _entries = [];
    _recentFoods = [];
    _recentFoodMeals.clear();
    invalidateCache();
    invalidateFoodHistoryCache();
  }

  Future<List<FoodEntry>> _addClonedEntries(
    List<FoodEntry> source, {
    required List<DateTime> timestamps,
  }) async {
    final entries = [
      for (var index = 0; index < source.length; index++)
        source[index].copyWith(
          id: const Uuid().v4(),
          timestamp: timestamps[index],
        ),
    ];
    return _addPreparedEntries(entries);
  }

  Future<List<FoodEntry>> _addPreparedEntries(List<FoodEntry> entries) async {
    if (entries.isEmpty) return const <FoodEntry>[];

    final added = <FoodEntry>[];
    try {
      for (final entry in entries) {
        await addFoodEntry(entry);
        added.add(entry);
      }
      return entries;
    } catch (_) {
      for (final entry in added.reversed) {
        await removeFoodEntry(entry.id);
      }
      rethrow;
    }
  }

  String _formatSelection(PortionSelection selection) {
    final amount = _formatNumber(selection.amount);
    final canonical = '$amount${selection.unit.symbol}';
    final label = selection.humanLabel;
    if (label == null || label.trim().isEmpty) return canonical;
    final quantity = selection.labelQuantity;
    final quantityText = quantity == null ? '' : '${_formatNumber(quantity)} ';
    return '$quantityText$label ($canonical)';
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  bool _sameCalendarDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
