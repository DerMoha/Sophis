import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/models/custom_portion.dart';
import 'package:sophis/services/nutrition/nutrition_persistence.dart';
import 'package:sophis/services/nutrition/nutrition_store.dart';

/// Manages recipes, custom foods, favorites, and custom portions.
class FoodLibraryController {
  final NutritionPersistence _persistence;
  final Future<void> Function() _onChanged;
  final NutritionStore? _store;

  List<Recipe> _recipes = [];
  List<FoodItem> _customFoods = [];
  List<FoodItem> _favoriteFoods = [];
  Set<String> _favoriteFoodIds = {};
  List<CustomPortion> _customPortions = [];

  FoodLibraryController(
    this._persistence,
    this._onChanged, {
    NutritionStore? store,
  }) : _store = store;

  List<Recipe> get recipes => _recipes;
  List<FoodItem> get customFoods => _customFoods;
  List<FoodItem> get favoriteFoods => _favoriteFoods;
  List<CustomPortion> get customPortions => _customPortions;

  void loadData({
    required List<Recipe> recipes,
    required List<FoodItem> customFoods,
    required List<FoodItem> favoriteFoods,
    required List<CustomPortion> customPortions,
  }) {
    _recipes = recipes;
    _customFoods = customFoods;
    _favoriteFoods = favoriteFoods;
    _favoriteFoodIds = favoriteFoods.map((f) => f.id).toSet();
    _customPortions = customPortions;
  }

  // Recipes
  Future<void> addRecipe(Recipe recipe) async {
    final updatedRecipes = [..._recipes, recipe];
    if (_store == null) {
      await _persistence.saveRecipes(updatedRecipes);
    } else {
      await _store!.commitOrThrow(SaveRecipe(recipe));
    }
    _recipes = updatedRecipes;
    await _onChanged();
  }

  Future<void> updateRecipe(Recipe recipe) async {
    final i = _recipes.indexWhere((r) => r.id == recipe.id);
    if (i != -1) {
      final updatedRecipes = List<Recipe>.of(_recipes)..[i] = recipe;
      if (_store == null) {
        await _persistence.saveRecipes(updatedRecipes);
      } else {
        await _store!.commitOrThrow(SaveRecipe(recipe));
      }
      _recipes = updatedRecipes;
      await _onChanged();
    }
  }

  Future<void> removeRecipe(String id) async {
    final updatedRecipes = _recipes.where((recipe) => recipe.id != id).toList();
    if (updatedRecipes.length == _recipes.length) return;

    if (_store == null) {
      await _persistence.saveRecipes(updatedRecipes);
    } else {
      await _store!.commitOrThrow(DeleteRecipe(id));
    }
    _recipes = updatedRecipes;
    await _onChanged();
  }

  // Custom Foods
  Future<void> addCustomFood(FoodItem food) async {
    if (_customFoods.any((f) => f.id == food.id)) return;
    final updatedFoods = [food, ..._customFoods];
    if (_store == null) {
      await _persistence.saveCustomFoods(updatedFoods);
    } else {
      await _store!.commitOrThrow(SaveCustomFood(food));
    }
    _customFoods = updatedFoods;
    await _onChanged();
  }

  Future<void> removeCustomFood(String id) async {
    final updatedFoods = _customFoods.where((food) => food.id != id).toList();
    if (updatedFoods.length == _customFoods.length) return;

    if (_store == null) {
      await _persistence.saveCustomFoods(updatedFoods);
    } else {
      await _store!.commitOrThrow(DeleteCustomFood(id));
    }
    _customFoods = updatedFoods;
    await _onChanged();
  }

  List<FoodItem> searchCustomFoods(String query) {
    if (query.isEmpty) return _customFoods;
    final lowerQuery = query.toLowerCase();
    return _customFoods
        .where((f) => f.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  // Favorites
  bool isFavorite(String id) {
    return _favoriteFoodIds.contains(id);
  }

  Future<void> addFavorite(FoodItem food) async {
    if (isFavorite(food.id)) return;
    final updatedFoods = [food.copyWith(isFavorite: true), ..._favoriteFoods];
    if (_store == null) {
      await _persistence.saveFavoriteFoods(updatedFoods);
    } else {
      await _store!.commitOrThrow(SaveFavoriteFood(food));
    }
    _favoriteFoods = updatedFoods;
    _favoriteFoodIds = updatedFoods.map((value) => value.id).toSet();
    await _onChanged();
  }

  Future<void> removeFavorite(String id) async {
    final updatedFoods = _favoriteFoods.where((food) => food.id != id).toList();
    if (updatedFoods.length == _favoriteFoods.length) return;

    if (_store == null) {
      await _persistence.saveFavoriteFoods(updatedFoods);
    } else {
      await _store!.commitOrThrow(DeleteFavoriteFood(id));
    }
    _favoriteFoods = updatedFoods;
    _favoriteFoodIds = updatedFoods.map((value) => value.id).toSet();
    await _onChanged();
  }

  Future<void> toggleFavorite(FoodItem food) async {
    if (isFavorite(food.id)) {
      await removeFavorite(food.id);
    } else {
      await addFavorite(food);
    }
  }

  // Custom Portions
  List<CustomPortion> getCustomPortionsForProduct(String productKey) {
    return _customPortions.where((p) => p.productKey == productKey).toList();
  }

  Future<void> addCustomPortion(CustomPortion portion) async {
    final updatedPortions = [..._customPortions, portion];
    if (_store == null) {
      await _persistence.saveCustomPortions(updatedPortions);
    } else {
      await _store!.commitOrThrow(SaveCustomPortion(portion));
    }
    _customPortions = updatedPortions;
    await _onChanged();
  }

  Future<void> removeCustomPortion(String id) async {
    final updatedPortions =
        _customPortions.where((portion) => portion.id != id).toList();
    if (updatedPortions.length == _customPortions.length) return;

    if (_store == null) {
      await _persistence.saveCustomPortions(updatedPortions);
    } else {
      await _store!.commitOrThrow(DeleteCustomPortion(id));
    }
    _customPortions = updatedPortions;
    await _onChanged();
  }

  void clearAll() {
    _recipes = [];
    _customFoods = [];
    _favoriteFoods = [];
    _favoriteFoodIds = {};
    _customPortions = [];
  }
}
