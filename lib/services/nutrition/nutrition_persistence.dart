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
/// coherent state. Library, planning, stats, and shopping rows are canonical;
/// the recent-food document remains a deliberately local-only cache because
/// it also stores meal-specific presentation metadata. Migration flags, Drift
/// rows, and legacy preference keys stay behind this interface.
class NutritionPersistence {
  static const _canonicalLibraryMigrationKey = 'canonical_library_rows_v1';
  static const _canonicalLibraryMigrationVersion = 1;
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

    final marker = await _database.getMigrationState(
      _canonicalLibraryMigrationKey,
    );
    if (marker?.version != _canonicalLibraryMigrationVersion) {
      // Documents are the only source that can contain complete favorite
      // snapshots during the cutover. Stage all normalized rows in one
      // transaction, then write the marker last so a failed migration retries
      // safely on the next launch.
      final state = await _loadDocumentState();
      await _database.transaction(() async {
        await _writeCanonicalRows(state, transactional: false);
        await _database.setMigrationState(
          _canonicalLibraryMigrationKey,
          version: _canonicalLibraryMigrationVersion,
        );
      });
    }
    return load();
  }

  Future<NutritionPersistentState> load() async {
    final marker = await _database.getMigrationState(
      _canonicalLibraryMigrationKey,
    );
    if (marker?.version != _canonicalLibraryMigrationVersion) {
      final hasCanonicalRows = await _hasCanonicalRows();
      if (!hasCanonicalRows) return _loadDocumentState();
    }

    final recentDocument = await _readMap(_recentFoodsKey);
    final recentFoods = (recentDocument?['foods'] as List<dynamic>? ?? const [])
        .map((value) => FoodItem.fromJson(value as Map<String, dynamic>))
        .toList();
    final recentMeals = (recentDocument?['meals'] as Map<String, dynamic>? ??
            const <String, dynamic>{})
        .map((key, value) => MapEntry(key, value as String));

    final customRows = await _database.getAllCustomFoods();
    final customFoods = customRows.map(_foodFromCustomRow).toList();
    final foodsById = {for (final food in customFoods) food.id: food};
    final favoriteRows = await _database.getAllFavoriteFoods();
    final favoriteFoods = <FoodItem>[];
    for (final row in favoriteRows) {
      final json = row.foodJson;
      if (json != null && json.isNotEmpty) {
        favoriteFoods.add(
          FoodItem.fromJson(jsonDecode(json) as Map<String, dynamic>)
              .copyWith(isFavorite: true),
        );
      } else {
        final fallback = foodsById[row.id];
        if (fallback != null) {
          favoriteFoods.add(fallback.copyWith(isFavorite: true));
        }
      }
    }

    final recipeRows = await _database.getAllRecipes();
    final plannedRows = await _database.getAllPlannedMeals();
    final portionRows = await _database.getAllCustomPortions();
    final statsRow = await _database.getUserStats();
    final checkedRows = await _database.getPlannedMealsChecked();

    return NutritionPersistentState(
      recipes: recipeRows.map(_recipeFromRow).toList(),
      customFoods: customFoods,
      favoriteFoods: favoriteFoods,
      plannedMeals: plannedRows.map(_plannedMealFromRow).toList(),
      customPortions: portionRows.map(_customPortionFromRow).toList(),
      recentFoods: recentFoods,
      recentFoodMeals: recentMeals,
      userStats:
          statsRow == null ? const UserStats() : _userStatsFromRow(statsRow),
      shoppingListChecked: checkedRows.toSet(),
    );
  }

  Future<void> saveRecipes(
    List<Recipe> recipes, {
    bool transactional = true,
  }) async {
    final rows = recipes.map(_recipeToRow).toList();
    await _database.replaceRecipes(rows, transactional: transactional);
  }

  Future<void> upsertRecipe(
    Recipe recipe, {
    bool transactional = true,
  }) async {
    Future<void> write() => _database.upsertRecipe(_recipeToRow(recipe));
    if (transactional) {
      await _database.transaction(write);
    } else {
      await write();
    }
  }

  Future<void> deleteRecipe(
    String id, {
    bool transactional = true,
  }) async {
    Future<void> write() async {
      await _database.deleteRecipe(id);
    }

    if (transactional) {
      await _database.transaction(write);
    } else {
      await write();
    }
  }

  Future<void> saveCustomFoods(
    List<FoodItem> foods, {
    bool transactional = true,
  }) async {
    final rows = foods.map(_customFoodToRow).toList();
    await _database.replaceCustomFoods(rows, transactional: transactional);
  }

  Future<void> upsertCustomFood(
    FoodItem food, {
    bool transactional = true,
  }) async {
    Future<void> write() => _database.upsertCustomFood(_customFoodToRow(food));
    if (transactional) {
      await _database.transaction(write);
    } else {
      await write();
    }
  }

  Future<void> deleteCustomFood(
    String id, {
    bool transactional = true,
  }) async {
    Future<void> write() async {
      await _database.deleteCustomFood(id);
    }

    if (transactional) {
      await _database.transaction(write);
    } else {
      await write();
    }
  }

  Future<void> saveFavoriteFoods(
    List<FoodItem> foods, {
    bool transactional = true,
  }) async {
    final rows = foods.map(_favoriteFoodToRow).toList();
    await _database.replaceFavoriteFoods(rows, transactional: transactional);
  }

  Future<void> upsertFavoriteFood(
    FoodItem food, {
    bool transactional = true,
  }) async {
    Future<void> write() =>
        _database.upsertFavoriteFood(_favoriteFoodToRow(food));
    if (transactional) {
      await _database.transaction(write);
    } else {
      await write();
    }
  }

  Future<void> deleteFavoriteFood(
    String id, {
    bool transactional = true,
  }) async {
    Future<void> write() async {
      await _database.deleteFavoriteFood(id);
    }

    if (transactional) {
      await _database.transaction(write);
    } else {
      await write();
    }
  }

  Future<void> savePlannedMeals(
    List<PlannedMeal> meals, {
    bool transactional = true,
  }) async {
    final rows = meals.map(_plannedMealToRow).toList();
    await _database.replacePlannedMeals(rows, transactional: transactional);
  }

  Future<void> upsertPlannedMeal(
    PlannedMeal meal, {
    bool transactional = true,
  }) async {
    Future<void> write() =>
        _database.upsertPlannedMeal(_plannedMealToRow(meal));
    if (transactional) {
      await _database.transaction(write);
    } else {
      await write();
    }
  }

  Future<void> upsertPlannedMeals(
    Iterable<PlannedMeal> meals, {
    bool transactional = true,
  }) async {
    final rows = meals.map(_plannedMealToRow).toList();
    if (rows.isEmpty) return;

    Future<void> write() => _database.upsertPlannedMeals(rows);
    if (transactional) {
      await _database.transaction(write);
    } else {
      await write();
    }
  }

  Future<void> deletePlannedMeal(
    String id, {
    bool transactional = true,
  }) async {
    Future<void> write() async {
      await _database.deletePlannedMeal(id);
    }

    if (transactional) {
      await _database.transaction(write);
    } else {
      await write();
    }
  }

  Future<void> saveCustomPortions(
    List<CustomPortion> portions, {
    bool transactional = true,
  }) async {
    final rows = portions.map(_customPortionToRow).toList();
    await _database.replaceCustomPortions(rows, transactional: transactional);
  }

  Future<void> upsertCustomPortion(
    CustomPortion portion, {
    bool transactional = true,
  }) async {
    Future<void> write() =>
        _database.upsertCustomPortion(_customPortionToRow(portion));
    if (transactional) {
      await _database.transaction(write);
    } else {
      await write();
    }
  }

  Future<void> deleteCustomPortion(
    String id, {
    bool transactional = true,
  }) async {
    Future<void> write() async {
      await _database.deleteCustomPortion(id);
    }

    if (transactional) {
      await _database.transaction(write);
    } else {
      await write();
    }
  }

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

  Future<void> saveUserStats(UserStats stats) => _database.upsertUserStats(
        _userStatsToRow(stats),
      );

  Future<void> saveShoppingListChecked(
    Set<String> checked, {
    bool transactional = true,
  }) =>
      _database.replacePlannedMealsChecked(
        checked.toList()..sort(),
        transactional: transactional,
      );

  Future<NutritionPersistentState> _loadDocumentState() async {
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

  Future<bool> _hasCanonicalRows() async {
    final recipes = await _database.getAllRecipes();
    if (recipes.isNotEmpty) return true;
    final customFoods = await _database.getAllCustomFoods();
    if (customFoods.isNotEmpty) return true;
    final favorites = await _database.getAllFavoriteFoods();
    if (favorites.isNotEmpty) return true;
    final plannedMeals = await _database.getAllPlannedMeals();
    if (plannedMeals.isNotEmpty) return true;
    final portions = await _database.getAllCustomPortions();
    if (portions.isNotEmpty) return true;
    final stats = await _database.getUserStats();
    if (stats != null) return true;
    final checked = await _database.getPlannedMealsChecked();
    return checked.isNotEmpty;
  }

  Future<void> _writeCanonicalRows(
    NutritionPersistentState state, {
    required bool transactional,
  }) async {
    await _database.replaceRecipes(
      state.recipes.map(_recipeToRow).toList(),
      transactional: transactional,
    );
    await _database.replaceCustomFoods(
      state.customFoods.map(_customFoodToRow).toList(),
      transactional: transactional,
    );
    await _database.replaceFavoriteFoods(
      state.favoriteFoods.map(_favoriteFoodToRow).toList(),
      transactional: transactional,
    );
    await _database.replacePlannedMeals(
      state.plannedMeals.map(_plannedMealToRow).toList(),
      transactional: transactional,
    );
    await _database.replaceCustomPortions(
      state.customPortions.map(_customPortionToRow).toList(),
      transactional: transactional,
    );
    await _database.upsertUserStats(_userStatsToRow(state.userStats));
    await _database.replacePlannedMealsChecked(
      state.shoppingListChecked.toList()..sort(),
      transactional: false,
    );
  }

  Future<void> _reconcileLegacyState() async {
    final preferences = _legacyStorage.loadLegacyNutritionState();
    final sqlite = await _loadLegacySqliteState();
    final current = await _loadDocumentState();

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

  RecipeRow _recipeToRow(Recipe recipe) => RecipeRow(
        id: recipe.id,
        name: recipe.name,
        ingredientsJson: jsonEncode(
          recipe.ingredients.map((ingredient) => ingredient.toJson()).toList(),
        ),
        servings: recipe.servings,
        notes: recipe.notes,
        createdAt: recipe.createdAt.toUtc(),
      );

  Recipe _recipeFromRow(RecipeRow row) => Recipe(
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
      );

  CustomFoodRow _customFoodToRow(FoodItem food) => CustomFoodRow(
        id: food.id,
        name: food.name,
        category: food.category,
        caloriesPer100g: food.caloriesPer100g,
        proteinPer100g: food.proteinPer100g,
        carbsPer100g: food.carbsPer100g,
        fatPer100g: food.fatPer100g,
        fiberPer100g: food.fiberPer100g,
        barcode: food.barcode,
        brand: food.brand,
        imageUrl: food.imageUrl,
        servingsJson: jsonEncode(
          food.servings.map((serving) => serving.toJson()).toList(),
        ),
      );

  FavoriteFoodRow _favoriteFoodToRow(FoodItem food) => FavoriteFoodRow(
        id: food.id,
        foodJson: jsonEncode(food.copyWith(isFavorite: true).toJson()),
      );

  PlannedMealRow _plannedMealToRow(PlannedMeal meal) => PlannedMealRow(
        id: meal.id,
        date: meal.date.toUtc(),
        meal: meal.meal,
        name: meal.name,
        calories: meal.calories,
        protein: meal.protein,
        carbs: meal.carbs,
        fat: meal.fat,
        fiber: meal.fiber,
        recipeId: meal.recipeId,
        servings: meal.servings,
        ingredientsJson: jsonEncode(
          meal.ingredients.map((ingredient) => ingredient.toJson()).toList(),
        ),
      );

  PlannedMeal _plannedMealFromRow(PlannedMealRow row) => PlannedMeal(
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
      );

  CustomPortionRow _customPortionToRow(CustomPortion portion) =>
      CustomPortionRow(
        id: portion.id,
        productKey: portion.productKey,
        name: portion.name,
        grams: portion.grams,
        createdAt: portion.createdAt.toUtc(),
      );

  CustomPortion _customPortionFromRow(CustomPortionRow row) => CustomPortion(
        id: row.id,
        productKey: row.productKey,
        name: row.name,
        grams: row.grams,
        createdAt: row.createdAt,
      );

  UserStatsRow _userStatsToRow(UserStats stats) => UserStatsRow(
        id: 'default',
        currentStreak: stats.currentStreak,
        longestStreak: stats.longestStreak,
        lastLogDate: stats.lastLogDate?.toUtc(),
        achievementsJson: jsonEncode(stats.achievements),
        totalDaysLogged: stats.totalDaysLogged,
      );

  UserStats _userStatsFromRow(UserStatsRow row) => UserStats(
        currentStreak: row.currentStreak,
        longestStreak: row.longestStreak,
        lastLogDate: row.lastLogDate,
        achievements:
            (jsonDecode(row.achievementsJson) as List<dynamic>).cast<String>(),
        totalDaysLogged: row.totalDaysLogged,
      );

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
          .map((row) => _favoriteFromRow(row, foodsById))
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

  FoodItem? _favoriteFromRow(
    FavoriteFoodRow row,
    Map<String, FoodItem> foodsById,
  ) {
    final json = row.foodJson;
    if (json != null && json.isNotEmpty) {
      return FoodItem.fromJson(jsonDecode(json) as Map<String, dynamic>)
          .copyWith(isFavorite: true);
    }
    return foodsById[row.id]?.copyWith(isFavorite: true);
  }

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
