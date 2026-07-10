import 'dart:convert';

import 'package:sophis/models/custom_portion.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/meal_plan.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/models/serving_size.dart';
import 'package:sophis/models/user_stats.dart';
import 'package:sophis/services/database_service.dart';
import 'package:sophis/services/storage_service.dart';

/// SQLite-backed authority for nutrition collections that are loaded as a
/// coherent state. Its interface deliberately hides migration flags, Drift
/// rows, JSON documents, and legacy preference keys from callers.
class NutritionPersistence {
  static const _recipesKey = 'recipes';
  static const _customFoodsKey = 'custom_foods';
  static const _favoriteFoodsKey = 'favorite_foods';
  static const _plannedMealsKey = 'planned_meals';
  static const _customPortionsKey = 'custom_portions';
  static const _recentFoodsKey = 'recent_foods';
  static const _userStatsKey = 'user_stats';
  static const _shoppingListKey = 'shopping_list_checked';

  final DatabaseService _database;
  final StorageService _legacyStorage;

  NutritionPersistence(this._database, this._legacyStorage);

  Future<NutritionPersistentState> initialize() async {
    if (!_legacyStorage.isMigrationV3Complete()) {
      await _reconcileLegacyState();
    }
    return load();
  }

  Future<NutritionPersistentState> load() async {
    final recentDocument = await _readMap(_recentFoodsKey);
    final recentFoods = (recentDocument?['foods'] as List<dynamic>? ?? const [])
        .map((value) => FoodItem.fromJson(value as Map<String, dynamic>))
        .toList();
    final recentMeals = (recentDocument?['meals'] as Map<String, dynamic>? ??
            const <String, dynamic>{})
        .map((key, value) => MapEntry(key, value as String));

    return NutritionPersistentState(
      recipes: await _readList(_recipesKey, Recipe.fromJson),
      customFoods: await _readList(_customFoodsKey, FoodItem.fromJson),
      favoriteFoods: await _readList(_favoriteFoodsKey, FoodItem.fromJson),
      plannedMeals: await _readList(_plannedMealsKey, PlannedMeal.fromJson),
      customPortions:
          await _readList(_customPortionsKey, CustomPortion.fromJson),
      recentFoods: recentFoods,
      recentFoodMeals: recentMeals,
      userStats: await _readObject(
        _userStatsKey,
        UserStats.fromJson,
        const UserStats(),
      ),
      shoppingListChecked: (await _readRawList(_shoppingListKey))
          .map((value) => value as String)
          .toSet(),
    );
  }

  Future<void> saveRecipes(List<Recipe> recipes) =>
      _writeList(_recipesKey, recipes.map((value) => value.toJson()));

  Future<void> saveCustomFoods(List<FoodItem> foods) =>
      _writeList(_customFoodsKey, foods.map((value) => value.toJson()));

  Future<void> saveFavoriteFoods(List<FoodItem> foods) =>
      _writeList(_favoriteFoodsKey, foods.map((value) => value.toJson()));

  Future<void> savePlannedMeals(List<PlannedMeal> meals) =>
      _writeList(_plannedMealsKey, meals.map((value) => value.toJson()));

  Future<void> saveCustomPortions(List<CustomPortion> portions) =>
      _writeList(_customPortionsKey, portions.map((value) => value.toJson()));

  Future<void> saveRecentFoods(
    List<FoodItem> foods,
    Map<String, String> meals,
  ) {
    final limitedFoods = foods.take(20).toList();
    final limitedIds = limitedFoods.map((food) => food.id).toSet();
    return _database.writeNutritionDocument(
      _recentFoodsKey,
      jsonEncode({
        'foods': limitedFoods.map((food) => food.toJson()).toList(),
        'meals': Map<String, String>.fromEntries(
          meals.entries.where((entry) => limitedIds.contains(entry.key)),
        ),
      }),
    );
  }

  Future<void> saveUserStats(UserStats stats) =>
      _writeObject(_userStatsKey, stats.toJson());

  Future<void> saveShoppingListChecked(Set<String> checked) =>
      _writeList(_shoppingListKey, checked.toList()..sort());

  Future<void> _reconcileLegacyState() async {
    final preferences = _legacyStorage.loadLegacyNutritionState();
    final sqlite = await _loadLegacySqliteState();
    final current = await load();

    final state = NutritionPersistentState(
      recipes: _choose(
        preferences.recipes,
        current.recipes,
        sqlite.recipes,
      ),
      customFoods: _choose(
        preferences.customFoods,
        current.customFoods,
        sqlite.customFoods,
      ),
      favoriteFoods: _choose(
        preferences.favoriteFoods,
        current.favoriteFoods,
        sqlite.favoriteFoods,
      ),
      plannedMeals: _choose(
        preferences.plannedMeals,
        current.plannedMeals,
        sqlite.plannedMeals,
      ),
      customPortions: _choose(
        preferences.customPortions,
        current.customPortions,
        sqlite.customPortions,
      ),
      recentFoods: preferences.recentFoods.isPresent
          ? preferences.recentFoods.value.foods
          : current.recentFoods.isNotEmpty
              ? current.recentFoods
              : sqlite.recentFoods,
      recentFoodMeals: preferences.recentFoods.isPresent
          ? preferences.recentFoods.value.meals
          : current.recentFoods.isNotEmpty
              ? current.recentFoodMeals
              : sqlite.recentFoodMeals,
      userStats: preferences.userStats.isPresent
          ? preferences.userStats.value
          : _hasStats(current.userStats)
              ? current.userStats
              : sqlite.userStats,
      shoppingListChecked: _chooseSet(
        preferences.shoppingListChecked,
        current.shoppingListChecked,
        sqlite.shoppingListChecked,
      ),
    );

    final documents = _encodeState(state);
    await _database.writeNutritionDocuments(documents);
    for (final entry in documents.entries) {
      final stored = await _database.readNutritionDocument(entry.key);
      if (stored != entry.value) {
        throw StateError('Failed to verify nutrition migration: ${entry.key}');
      }
    }

    await _legacyStorage.setMigrationV3Complete();
    await _legacyStorage.clearLegacyMigratedV2Data();
  }

  List<T> _choose<T>(
    LegacyValue<List<T>> preference,
    List<T> current,
    List<T> sqlite,
  ) {
    if (preference.isPresent) return preference.value;
    if (current.isNotEmpty) return current;
    return sqlite;
  }

  Set<T> _chooseSet<T>(
    LegacyValue<Set<T>> preference,
    Set<T> current,
    Set<T> sqlite,
  ) {
    if (preference.isPresent) return preference.value;
    if (current.isNotEmpty) return current;
    return sqlite;
  }

  bool _hasStats(UserStats stats) =>
      stats.currentStreak != 0 ||
      stats.longestStreak != 0 ||
      stats.lastLogDate != null ||
      stats.achievements.isNotEmpty ||
      stats.totalDaysLogged != 0;

  Map<String, String> _encodeState(NutritionPersistentState state) => {
        _recipesKey:
            jsonEncode(state.recipes.map((value) => value.toJson()).toList()),
        _customFoodsKey: jsonEncode(
          state.customFoods.map((value) => value.toJson()).toList(),
        ),
        _favoriteFoodsKey: jsonEncode(
          state.favoriteFoods.map((value) => value.toJson()).toList(),
        ),
        _plannedMealsKey: jsonEncode(
          state.plannedMeals.map((value) => value.toJson()).toList(),
        ),
        _customPortionsKey: jsonEncode(
          state.customPortions.map((value) => value.toJson()).toList(),
        ),
        _recentFoodsKey: jsonEncode({
          'foods': state.recentFoods.map((value) => value.toJson()).toList(),
          'meals': state.recentFoodMeals,
        }),
        _userStatsKey: jsonEncode(state.userStats.toJson()),
        _shoppingListKey:
            jsonEncode(state.shoppingListChecked.toList()..sort()),
      };

  Future<NutritionPersistentState> _loadLegacySqliteState() async {
    final recipeRows = await _database.getAllRecipes();
    final customRows = await _database.getAllCustomFoods();
    final favoriteRows = await _database.getAllFavoriteFoods();
    final plannedRows = await _database.getAllPlannedMeals();
    final portionRows = await _database.getAllCustomPortions();
    final recentRows = await _database.getAllRecentFoods();
    final statsRow = await _database.getUserStats();
    final checkedRows = await _database.getPlannedMealsChecked();

    final customFoods = customRows.map(_foodFromCustomRow).toList();
    final recentFoods = recentRows.map(_foodFromRecentRow).toList();
    final foodsById = {
      for (final food in [...customFoods, ...recentFoods]) food.id: food,
    };

    return NutritionPersistentState(
      recipes: recipeRows
          .map(
            (row) => Recipe(
              id: row.id,
              name: row.name,
              ingredients: (jsonDecode(row.ingredientsJson) as List<dynamic>)
                  .map(
                    (value) => RecipeIngredient.fromJson(
                      value as Map<String, dynamic>,
                    ),
                  )
                  .toList(),
              servings: row.servings,
              notes: row.notes,
              createdAt: row.createdAt,
            ),
          )
          .toList(),
      customFoods: customFoods,
      favoriteFoods: favoriteRows
          .map((row) => foodsById[row.id]?.copyWith(isFavorite: true))
          .whereType<FoodItem>()
          .toList(),
      plannedMeals: plannedRows
          .map(
            (row) => PlannedMeal(
              id: row.id,
              date: row.date,
              meal: row.meal,
              name: row.name,
              calories: row.calories,
              protein: row.protein,
              carbs: row.carbs,
              fat: row.fat,
              fiber: row.fiber,
              recipeId: row.recipeId,
              servings: row.servings,
              ingredients: (jsonDecode(row.ingredientsJson) as List<dynamic>)
                  .map(
                    (value) => PlannedMealIngredient.fromJson(
                      value as Map<String, dynamic>,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
      customPortions: portionRows
          .map(
            (row) => CustomPortion(
              id: row.id,
              productKey: row.productKey,
              name: row.name,
              grams: row.grams,
              createdAt: row.createdAt,
            ),
          )
          .toList(),
      recentFoods: recentFoods,
      recentFoodMeals: const {},
      userStats: statsRow == null
          ? const UserStats()
          : UserStats(
              currentStreak: statsRow.currentStreak,
              longestStreak: statsRow.longestStreak,
              lastLogDate: statsRow.lastLogDate,
              achievements:
                  (jsonDecode(statsRow.achievementsJson) as List<dynamic>)
                      .cast<String>(),
              totalDaysLogged: statsRow.totalDaysLogged,
            ),
      shoppingListChecked: checkedRows.toSet(),
    );
  }

  FoodItem _foodFromCustomRow(CustomFoodRow row) => FoodItem(
        id: row.id,
        name: row.name,
        category: row.category,
        caloriesPer100g: row.caloriesPer100g,
        proteinPer100g: row.proteinPer100g,
        carbsPer100g: row.carbsPer100g,
        fatPer100g: row.fatPer100g,
        fiberPer100g: row.fiberPer100g,
        barcode: row.barcode,
        brand: row.brand,
        imageUrl: row.imageUrl,
        servings: _decodeServings(row.servingsJson),
      );

  FoodItem _foodFromRecentRow(RecentFoodRow row) => FoodItem(
        id: row.id,
        name: row.name,
        category: row.category,
        caloriesPer100g: row.caloriesPer100g,
        proteinPer100g: row.proteinPer100g,
        carbsPer100g: row.carbsPer100g,
        fatPer100g: row.fatPer100g,
        fiberPer100g: row.fiberPer100g,
        barcode: row.barcode,
        brand: row.brand,
        imageUrl: row.imageUrl,
        servings: _decodeServings(row.servingsJson),
      );

  List<ServingSize> _decodeServings(String? value) {
    if (value == null || value.isEmpty) return const [];
    return (jsonDecode(value) as List<dynamic>)
        .map(
          (serving) => ServingSize.fromJson(serving as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<T>> _readList<T>(
    String key,
    T Function(Map<String, dynamic>) decode,
  ) async {
    final values = await _readRawList(key);
    return values
        .map((value) => decode(value as Map<String, dynamic>))
        .toList();
  }

  Future<List<dynamic>> _readRawList(String key) async {
    final value = await _database.readNutritionDocument(key);
    if (value == null) return const [];
    return jsonDecode(value) as List<dynamic>;
  }

  Future<Map<String, dynamic>?> _readMap(String key) async {
    final value = await _database.readNutritionDocument(key);
    if (value == null) return null;
    return jsonDecode(value) as Map<String, dynamic>;
  }

  Future<T> _readObject<T>(
    String key,
    T Function(Map<String, dynamic>) decode,
    T fallback,
  ) async {
    final value = await _database.readNutritionDocument(key);
    if (value == null) return fallback;
    return decode(jsonDecode(value) as Map<String, dynamic>);
  }

  Future<void> _writeList(String key, Iterable<Object?> values) =>
      _database.writeNutritionDocument(key, jsonEncode(values.toList()));

  Future<void> _writeObject(String key, Map<String, dynamic> value) =>
      _database.writeNutritionDocument(key, jsonEncode(value));
}

class NutritionPersistentState {
  final List<Recipe> recipes;
  final List<FoodItem> customFoods;
  final List<FoodItem> favoriteFoods;
  final List<PlannedMeal> plannedMeals;
  final List<CustomPortion> customPortions;
  final List<FoodItem> recentFoods;
  final Map<String, String> recentFoodMeals;
  final UserStats userStats;
  final Set<String> shoppingListChecked;

  const NutritionPersistentState({
    required this.recipes,
    required this.customFoods,
    required this.favoriteFoods,
    required this.plannedMeals,
    required this.customPortions,
    required this.recentFoods,
    required this.recentFoodMeals,
    required this.userStats,
    required this.shoppingListChecked,
  });
}
