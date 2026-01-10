import 'package:flutter/foundation.dart';
import '../models/nutrition_goals.dart';
import '../models/food_entry.dart';
import '../models/user_profile.dart';
import '../models/water_entry.dart';
import '../models/weight_entry.dart';
import '../models/recipe.dart';
import '../models/meal_plan.dart';
import '../models/custom_portion.dart';
import '../models/food_item.dart';
import 'storage_service.dart';
import 'health_service.dart';

/// Central state management for nutrition tracking
class NutritionProvider extends ChangeNotifier {
  final StorageService _storage;

  NutritionGoals? _goals;
  UserProfile? _profile;
  List<FoodEntry> _entries = [];
  List<WaterEntry> _waterEntries = [];
  List<WeightEntry> _weightEntries = [];
  List<Recipe> _recipes = [];
  List<PlannedMeal> _plannedMeals = [];
  Set<String> _shoppingListChecked = {};
  List<CustomPortion> _customPortions = [];
  List<FoodItem> _recentFoods = [];

  // Burned calories from health apps
  double _burnedCalories = 0.0;
  final HealthService _healthService = HealthService();

  // ═══════════════════════════════════════════════════════════════════════════
  // CACHING - Avoid repeated filtering on every build
  // ═══════════════════════════════════════════════════════════════════════════
  List<FoodEntry>? _cachedTodayEntries;
  Map<String, double>? _cachedTodayTotals;
  Map<String, List<FoodEntry>>? _cachedMealEntries;
  DateTime? _cacheDate; // Track which day the cache is for

  /// Invalidate cache when entries change or day changes
  void _invalidateCache() {
    _cachedTodayEntries = null;
    _cachedTodayTotals = null;
    _cachedMealEntries = null;
  }

  /// Check if cache is still valid for today
  bool _isCacheValid() {
    if (_cacheDate == null) return false;
    final now = DateTime.now();
    return _cacheDate!.year == now.year &&
        _cacheDate!.month == now.month &&
        _cacheDate!.day == now.day;
  }

  NutritionProvider(this._storage) {
    _loadData();
  }

  // Getters
  NutritionGoals? get goals => _goals;
  UserProfile? get profile => _profile;
  List<FoodEntry> get entries => _entries;
  List<WaterEntry> get waterEntries => _waterEntries;
  List<WeightEntry> get weightEntries => _weightEntries;
  List<Recipe> get recipes => _recipes;
  List<PlannedMeal> get plannedMeals => _plannedMeals;
  Set<String> get shoppingListChecked => _shoppingListChecked;
  List<CustomPortion> get customPortions => _customPortions;
  List<FoodItem> get recentFoods => _recentFoods;
  double get burnedCalories => _burnedCalories;
  StorageService get storage => _storage;

  /// Reload all data from storage (used after import)
  Future<void> reloadAll() async {
    _loadData();
  }

  void _loadData() {
    _goals = _storage.loadGoals();
    _profile = _storage.loadProfile();
    _entries = _storage.loadFoodEntries();
    _waterEntries = _storage.loadWaterEntries();
    _weightEntries = _storage.loadWeightEntries();
    _recipes = _storage.loadRecipes();
    _plannedMeals = _storage.loadPlannedMeals();
    _shoppingListChecked = _storage.loadShoppingListChecked();
    _customPortions = _storage.loadCustomPortions();
    _recentFoods = _storage.loadRecentFoods();
    _invalidateCache(); // Clear cache when loading fresh data
    notifyListeners();
  }

  // Goals
  Future<void> setGoals(NutritionGoals goals) async {
    _goals = goals;
    await _storage.saveGoals(goals);
    notifyListeners();
  }

  // Profile
  Future<void> setProfile(UserProfile profile) async {
    _profile = profile;
    await _storage.saveProfile(profile);
    notifyListeners();
  }

  // Food Entries
  Future<void> addFoodEntry(FoodEntry entry) async {
    _entries.add(entry);
    _invalidateCache(); // Clear cache when entries change
    await _storage.saveFoodEntries(_entries);
    notifyListeners();
  }

  Future<void> removeFoodEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    _invalidateCache(); // Clear cache when entries change
    await _storage.saveFoodEntries(_entries);
    notifyListeners();
  }

  List<FoodEntry> getTodayEntries() {
    // Use cached value if valid
    if (_isCacheValid() && _cachedTodayEntries != null) {
      return _cachedTodayEntries!;
    }

    // Rebuild cache
    final now = DateTime.now();
    _cacheDate = now;
    _cachedTodayEntries = _entries.where((e) =>
      e.timestamp.year == now.year &&
      e.timestamp.month == now.month &&
      e.timestamp.day == now.day
    ).toList();

    // Also pre-compute meal entries while we're at it
    _cachedMealEntries = {};
    for (final entry in _cachedTodayEntries!) {
      _cachedMealEntries!.putIfAbsent(entry.meal, () => []).add(entry);
    }

    return _cachedTodayEntries!;
  }

  List<FoodEntry> getEntriesForDate(DateTime date) {
    // For non-today dates, don't use cache
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return getTodayEntries();
    }
    return _entries.where((e) =>
      e.timestamp.year == date.year &&
      e.timestamp.month == date.month &&
      e.timestamp.day == date.day
    ).toList();
  }

  List<FoodEntry> getEntriesByMeal(String meal) {
    // Ensure cache is populated
    getTodayEntries();

    // Return cached meal entries or empty list
    if (_cachedMealEntries != null && _cachedMealEntries!.containsKey(meal)) {
      return _cachedMealEntries![meal]!;
    }
    return [];
  }

  Map<String, double> getTodayTotals() {
    // Use cached value if valid
    if (_isCacheValid() && _cachedTodayTotals != null) {
      return _cachedTodayTotals!;
    }

    // Compute and cache
    final today = getTodayEntries();
    double cal = 0, prot = 0, carb = 0, fat = 0;
    for (final e in today) {
      cal += e.calories;
      prot += e.protein;
      carb += e.carbs;
      fat += e.fat;
    }
    _cachedTodayTotals = {'calories': cal, 'protein': prot, 'carbs': carb, 'fat': fat};
    return _cachedTodayTotals!;
  }

  Map<String, double> getTotalsForDate(DateTime date) {
    final entries = getEntriesForDate(date);
    double cal = 0, prot = 0, carb = 0, fat = 0;
    for (final e in entries) {
      cal += e.calories;
      prot += e.protein;
      carb += e.carbs;
      fat += e.fat;
    }
    return {'calories': cal, 'protein': prot, 'carbs': carb, 'fat': fat};
  }

  double getRemainingCalories() {
    if (_goals == null) return 0;
    // Net remaining = goal - eaten + burned
    return _goals!.calories - getTodayTotals()['calories']! + _burnedCalories;
  }
  
  /// Refresh burned calories from health service (call on app open/resume)
  Future<void> refreshBurnedCalories({bool enabled = true}) async {
    if (!enabled) {
      _burnedCalories = 0.0;
      notifyListeners();
      return;
    }
    
    try {
      _burnedCalories = await _healthService.getTodayBurnedCalories();
      notifyListeners();
    } catch (e) {
      // Silently fail, keep previous value or 0
      debugPrint('Failed to fetch burned calories: $e');
    }
  }

  // Water
  Future<void> addWater(double ml) async {
    final entry = WaterEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amountMl: ml,
      timestamp: DateTime.now(),
    );
    _waterEntries.add(entry);
    await _storage.saveWaterEntries(_waterEntries);
    notifyListeners();
  }

  Future<void> removeWaterEntry(String id) async {
    _waterEntries.removeWhere((e) => e.id == id);
    await _storage.saveWaterEntries(_waterEntries);
    notifyListeners();
  }

  double getTodayWaterTotal() {
    final now = DateTime.now();
    return _waterEntries
        .where((e) =>
            e.timestamp.year == now.year &&
            e.timestamp.month == now.month &&
            e.timestamp.day == now.day)
        .fold(0.0, (sum, e) => sum + e.amountMl);
  }

  List<WaterEntry> getTodayWaterEntries() {
    final now = DateTime.now();
    return _waterEntries
        .where((e) =>
            e.timestamp.year == now.year &&
            e.timestamp.month == now.month &&
            e.timestamp.day == now.day)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // Weight
  Future<void> addWeight(double kg, {String? note}) async {
    final entry = WeightEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      weightKg: kg,
      timestamp: DateTime.now(),
      note: note,
    );
    _weightEntries.add(entry);
    _weightEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    await _storage.saveWeightEntries(_weightEntries);
    notifyListeners();
  }

  Future<void> removeWeightEntry(String id) async {
    _weightEntries.removeWhere((e) => e.id == id);
    await _storage.saveWeightEntries(_weightEntries);
    notifyListeners();
  }

  WeightEntry? get latestWeight =>
      _weightEntries.isEmpty ? null : _weightEntries.first;

  // Recipes
  Future<void> addRecipe(Recipe recipe) async {
    _recipes.add(recipe);
    await _storage.saveRecipes(_recipes);
    notifyListeners();
  }

  Future<void> updateRecipe(Recipe recipe) async {
    final i = _recipes.indexWhere((r) => r.id == recipe.id);
    if (i != -1) {
      _recipes[i] = recipe;
      await _storage.saveRecipes(_recipes);
      notifyListeners();
    }
  }

  Future<void> removeRecipe(String id) async {
    _recipes.removeWhere((r) => r.id == id);
    await _storage.saveRecipes(_recipes);
    notifyListeners();
  }

  Future<void> addRecipeAsMeal(Recipe recipe, int servings, String meal) async {
    final nutrients = recipe.nutrientsPerServing;
    final entry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${recipe.name} (${servings}x)',
      calories: nutrients['calories']! * servings,
      protein: nutrients['protein']! * servings,
      carbs: nutrients['carbs']! * servings,
      fat: nutrients['fat']! * servings,
      timestamp: DateTime.now(),
      meal: meal,
    );
    await addFoodEntry(entry);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MEAL PLANNING
  // ═══════════════════════════════════════════════════════════════════════════

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

  /// Get planned meals for a specific date
  List<PlannedMeal> getPlannedMealsForDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return _plannedMeals.where((m) {
      final mealDate = DateTime(m.date.year, m.date.month, m.date.day);
      return mealDate == normalized;
    }).toList();
  }

  /// Get planned meals for a date range (for week view)
  List<PlannedMeal> getPlannedMealsForRange(DateTime start, DateTime end) {
    final startNorm = DateTime(start.year, start.month, start.day);
    final endNorm = DateTime(end.year, end.month, end.day);
    return _plannedMeals.where((m) {
      final mealDate = DateTime(m.date.year, m.date.month, m.date.day);
      return !mealDate.isBefore(startNorm) && !mealDate.isAfter(endNorm);
    }).toList();
  }

  /// Get planned meals by meal type for a specific date
  List<PlannedMeal> getPlannedMealsByType(DateTime date, String meal) {
    return getPlannedMealsForDate(date).where((m) => m.meal == meal).toList();
  }

  /// Calculate totals for a planned day
  Map<String, double> getPlannedTotalsForDate(DateTime date) {
    final meals = getPlannedMealsForDate(date);
    double cal = 0, prot = 0, carb = 0, fat = 0;
    for (final m in meals) {
      cal += m.calories;
      prot += m.protein;
      carb += m.carbs;
      fat += m.fat;
    }
    return {'calories': cal, 'protein': prot, 'carbs': carb, 'fat': fat};
  }

  /// Copy a planned meal to another date
  Future<void> copyPlannedMealToDate(PlannedMeal meal, DateTime newDate) async {
    final newMeal = PlannedMeal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
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

  /// Copy all meals from one day to another
  Future<void> copyDayMeals(DateTime from, DateTime to) async {
    final meals = getPlannedMealsForDate(from);
    for (final meal in meals) {
      await copyPlannedMealToDate(meal, to);
    }
  }

  /// Convert a planned meal to a food entry (add to today's log)
  Future<void> logPlannedMeal(PlannedMeal planned) async {
    final entry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: planned.name,
      calories: planned.calories,
      protein: planned.protein,
      carbs: planned.carbs,
      fat: planned.fat,
      timestamp: DateTime.now(),
      meal: planned.meal,
    );
    await addFoodEntry(entry);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHOPPING LIST
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generate shopping list from planned meals in date range
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
        // Sort by category first, then by name
        final catCompare = a.category.compareTo(b.category);
        if (catCompare != 0) return catCompare;
        return a.name.compareTo(b.name);
      });
  }

  /// Toggle shopping list item checked state
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

  /// Clear all checked items
  Future<void> clearCheckedShoppingItems() async {
    _shoppingListChecked.clear();
    await _storage.saveShoppingListChecked(_shoppingListChecked);
    notifyListeners();
  }

  /// Check if a shopping item is checked
  bool isShoppingItemChecked(String name, String unit) {
    return _shoppingListChecked.contains('${name.toLowerCase()}_$unit');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CUSTOM PORTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get custom portions for a specific product
  List<CustomPortion> getCustomPortionsForProduct(String productKey) {
    return _customPortions.where((p) => p.productKey == productKey).toList();
  }

  /// Add a new custom portion
  Future<void> addCustomPortion(CustomPortion portion) async {
    _customPortions.add(portion);
    await _storage.saveCustomPortions(_customPortions);
    notifyListeners();
  }

  /// Remove a custom portion
  Future<void> removeCustomPortion(String id) async {
    _customPortions.removeWhere((p) => p.id == id);
    await _storage.saveCustomPortions(_customPortions);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RECENT FOODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Add a food to recent foods list (moves to top if already exists)
  Future<void> addRecentFood(FoodItem food) async {
    // Remove if already exists (we'll add it to the top)
    _recentFoods.removeWhere((f) => f.id == food.id);
    // Add to the beginning
    _recentFoods.insert(0, food);
    // Keep only last 20
    if (_recentFoods.length > 20) {
      _recentFoods = _recentFoods.take(20).toList();
    }
    await _storage.saveRecentFoods(_recentFoods);
    notifyListeners();
  }

  // Clear all
  Future<void> clearAllData() async {
    _goals = null;
    _profile = null;
    _entries = [];
    _waterEntries = [];
    _weightEntries = [];
    _recipes = [];
    _plannedMeals = [];
    _shoppingListChecked = {};
    _customPortions = [];
    _recentFoods = [];
    await _storage.clear();
    notifyListeners();
  }
}
