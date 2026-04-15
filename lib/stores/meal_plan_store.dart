import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:sophis/models/meal_plan.dart';
import 'package:sophis/models/nutrition_totals.dart';
import 'package:sophis/services/storage_service.dart';

class MealPlanStore extends ChangeNotifier {
  final StorageService _storage;

  List<PlannedMeal> _plannedMeals = [];
  Set<String> _shoppingListChecked = {};

  MealPlanStore(this._storage);

  List<PlannedMeal> get plannedMeals => _plannedMeals;
  Set<String> get shoppingListChecked => _shoppingListChecked;

  void loadData(
    List<PlannedMeal> plannedMeals,
    Set<String> shoppingListChecked,
  ) {
    _plannedMeals = plannedMeals;
    _shoppingListChecked = shoppingListChecked;
    notifyListeners();
  }

  Future<void> addPlannedMeal(PlannedMeal meal) async {
    _plannedMeals.add(meal);
    await _storage.savePlannedMeals(_plannedMeals);
    notifyListeners();
  }

  Future<void> removePlannedMeal(String id) async {
    _plannedMeals.removeWhere((m) => m.id == id);
    await _storage.savePlannedMeals(_plannedMeals);
    notifyListeners();
  }

  Future<void> updatePlannedMeal(PlannedMeal meal) async {
    final i = _plannedMeals.indexWhere((m) => m.id == meal.id);
    if (i != -1) {
      _plannedMeals[i] = meal;
      await _storage.savePlannedMeals(_plannedMeals);
      notifyListeners();
    }
  }

  List<PlannedMeal> getPlannedMealsForDate(DateTime date) {
    return _plannedMeals.where((m) {
      return m.date.year == date.year &&
          m.date.month == date.month &&
          m.date.day == date.day;
    }).toList();
  }

  bool hasPlannedMealsForDate(DateTime date) {
    return getPlannedMealsForDate(date).isNotEmpty;
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
    return getPlannedMealsForDate(date).where((m) => m.meal == meal).toList();
  }

  NutritionTotals getPlannedTotalsForDate(DateTime date) {
    final meals = getPlannedMealsForDate(date);
    var totals = NutritionTotals.zero;
    for (final meal in meals) {
      totals = totals +
          NutritionTotals(
            calories: meal.calories,
            protein: meal.protein,
            carbs: meal.carbs,
            fat: meal.fat,
          );
    }
    return totals;
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
    notifyListeners();
  }

  Future<void> clearCheckedShoppingItems() async {
    _shoppingListChecked.clear();
    await _storage.saveShoppingListChecked(_shoppingListChecked);
    notifyListeners();
  }

  bool isShoppingItemChecked(String name, String unit) {
    return _shoppingListChecked.contains('${name.toLowerCase()}_$unit');
  }

  void clearAll() {
    _plannedMeals = [];
    _shoppingListChecked = {};
  }
}
