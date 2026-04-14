import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:sophis/models/meal_plan.dart';
import 'package:sophis/models/nutrition_totals.dart';
import 'package:sophis/services/storage_service.dart';

/// Manages planned meals, shopping list, and planned meal cache.
class MealPlanController {
  final StorageService _storage;
  final VoidCallback _onChanged;
  final int Function(DateTime) _dayKey;

  List<PlannedMeal> _plannedMeals = [];
  Set<String> _shoppingListChecked = {};

  // Planned meal caches (indexed by YYYYMMDD key)
  Map<int, List<PlannedMeal>>? _plannedMealsByDateCache;
  Map<int, Map<String, List<PlannedMeal>>>? _plannedMealsByDateAndTypeCache;
  Map<int, NutritionTotals>? _plannedTotalsByDateCache;

  MealPlanController(
    this._storage,
    this._onChanged,
    this._dayKey,
  );

  static const _zeroMacroTotals = NutritionTotals.zero;

  List<PlannedMeal> get plannedMeals => _plannedMeals;
  Set<String> get shoppingListChecked => _shoppingListChecked;

  void loadData(
    List<PlannedMeal> plannedMeals,
    Set<String> shoppingListChecked,
  ) {
    _plannedMeals = plannedMeals;
    _shoppingListChecked = shoppingListChecked;
    invalidatePlannedMealsCache();
  }

  void invalidatePlannedMealsCache() {
    _plannedMealsByDateCache = null;
    _plannedMealsByDateAndTypeCache = null;
    _plannedTotalsByDateCache = null;
  }

  void _ensurePlannedMealsCache() {
    if (_plannedMealsByDateCache != null &&
        _plannedMealsByDateAndTypeCache != null &&
        _plannedTotalsByDateCache != null) {
      return;
    }

    final mealsByDate = <int, List<PlannedMeal>>{};
    final mealsByDateAndType = <int, Map<String, List<PlannedMeal>>>{};
    final totalsByDate = <int, NutritionTotals>{};

    for (final meal in _plannedMeals) {
      final key = _dayKey(meal.date);

      mealsByDate.putIfAbsent(key, () => []).add(meal);

      final byType = mealsByDateAndType.putIfAbsent(key, () => {});
      byType.putIfAbsent(meal.meal, () => []).add(meal);

      totalsByDate[key] = (totalsByDate[key] ?? _zeroMacroTotals) +
          NutritionTotals(
            calories: meal.calories,
            protein: meal.protein,
            carbs: meal.carbs,
            fat: meal.fat,
          );
    }

    _plannedMealsByDateCache = mealsByDate;
    _plannedMealsByDateAndTypeCache = mealsByDateAndType;
    _plannedTotalsByDateCache = totalsByDate;
  }

  Future<void> addPlannedMeal(PlannedMeal meal) async {
    _plannedMeals.add(meal);
    invalidatePlannedMealsCache();
    await _storage.savePlannedMeals(_plannedMeals);
    _onChanged();
  }

  Future<void> removePlannedMeal(String id) async {
    _plannedMeals.removeWhere((m) => m.id == id);
    invalidatePlannedMealsCache();
    await _storage.savePlannedMeals(_plannedMeals);
    _onChanged();
  }

  Future<void> updatePlannedMeal(PlannedMeal meal) async {
    final i = _plannedMeals.indexWhere((m) => m.id == meal.id);
    if (i != -1) {
      _plannedMeals[i] = meal;
      invalidatePlannedMealsCache();
      await _storage.savePlannedMeals(_plannedMeals);
      _onChanged();
    }
  }

  List<PlannedMeal> getPlannedMealsForDate(DateTime date) {
    _ensurePlannedMealsCache();
    return List.unmodifiable(
      _plannedMealsByDateCache![_dayKey(date)] ?? const <PlannedMeal>[],
    );
  }

  bool hasPlannedMealsForDate(DateTime date) {
    _ensurePlannedMealsCache();
    final meals = _plannedMealsByDateCache![_dayKey(date)];
    return meals != null && meals.isNotEmpty;
  }

  List<PlannedMeal> getPlannedMealsForRange(DateTime start, DateTime end) {
    final startNorm = DateTime(start.year, start.month, start.day);
    final endNorm = DateTime(end.year, end.month, end.day);
    return _plannedMeals.where((m) {
      final mealDate = DateTime(m.date.year, m.date.month, m.date.day);
      return !mealDate.isBefore(startNorm) && !mealDate.isAfter(endNorm);
    }).toList();
  }

  List<PlannedMeal> getPlannedMealsByType(DateTime date, String meal) {
    _ensurePlannedMealsCache();
    return List.unmodifiable(
      _plannedMealsByDateAndTypeCache![_dayKey(date)]?[meal] ??
          const <PlannedMeal>[],
    );
  }

  NutritionTotals getPlannedTotalsForDate(DateTime date) {
    _ensurePlannedMealsCache();
    return _plannedTotalsByDateCache![_dayKey(date)] ?? _zeroMacroTotals;
  }

  Future<void> copyPlannedMealToDate(PlannedMeal meal, DateTime newDate) async {
    final newMeal = PlannedMeal(
      id: const Uuid().v4(),
      date: newDate,
      meal: meal.meal,
      name: meal.name,
      calories: meal.calories,
      protein: meal.protein,
      carbs: meal.carbs,
      fat: meal.fat,
      recipeId: meal.recipeId,
      servings: meal.servings,
      ingredients: meal.ingredients,
    );
    await addPlannedMeal(newMeal);
  }

  Future<void> copyDayMeals(DateTime from, DateTime to) async {
    final meals = getPlannedMealsForDate(from);
    for (final meal in meals) {
      await copyPlannedMealToDate(meal, to);
    }
  }

  /// Generate shopping list from planned meals in date range.
  List<ShoppingListItem> generateShoppingList(DateTime start, DateTime end) {
    final meals = getPlannedMealsForRange(start, end);
    final Map<String, ShoppingListItem> aggregated = {};

    for (final meal in meals) {
      for (final ingredient in meal.ingredients) {
        final key = '${ingredient.name.toLowerCase()}_${ingredient.unit}';
        if (aggregated.containsKey(key)) {
          final existing = aggregated[key]!;
          aggregated[key] = existing.copyWith(
            totalAmount: existing.totalAmount + ingredient.amount,
          );
        } else {
          aggregated[key] = ShoppingListItem(
            name: ingredient.name,
            totalAmount: ingredient.amount,
            unit: ingredient.unit,
            category: ingredient.category,
            isChecked: _shoppingListChecked.contains(key),
          );
        }
      }
    }

    return aggregated.values.toList()
      ..sort((a, b) {
        final catCompare = a.category.compareTo(b.category);
        if (catCompare != 0) return catCompare;
        return a.name.compareTo(b.name);
      });
  }

  Future<void> toggleShoppingItem(String name, String unit) async {
    final key = '${name.toLowerCase()}_$unit';
    if (_shoppingListChecked.contains(key)) {
      _shoppingListChecked.remove(key);
    } else {
      _shoppingListChecked.add(key);
    }
    await _storage.saveShoppingListChecked(_shoppingListChecked);
    _onChanged();
  }

  Future<void> clearCheckedShoppingItems() async {
    _shoppingListChecked.clear();
    await _storage.saveShoppingListChecked(_shoppingListChecked);
    _onChanged();
  }

  bool isShoppingItemChecked(String name, String unit) {
    return _shoppingListChecked.contains('${name.toLowerCase()}_$unit');
  }

  void clearAll() {
    _plannedMeals = [];
    _shoppingListChecked = {};
    invalidatePlannedMealsCache();
  }
}
