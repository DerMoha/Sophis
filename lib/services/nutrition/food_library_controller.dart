import 'package:flutter/foundation.dart';
import '../../models/food_item.dart';
import '../../models/recipe.dart';
import '../../models/custom_portion.dart';
import '../storage_service.dart';

/// Manages recipes, custom foods, favorites, and custom portions.
class FoodLibraryController {
  final StorageService _storage;
  final VoidCallback _onChanged;

  List<Recipe> _recipes = [];
  List<FoodItem> _customFoods = [];
  List<FoodItem> _favoriteFoods = [];
  Set<String> _favoriteFoodIds = {};
  List<CustomPortion> _customPortions = [];

  FoodLibraryController(this._storage, this._onChanged);

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
    _recipes.add(recipe);
    await _storage.saveRecipes(_recipes);
    _onChanged();
  }

  Future<void> updateRecipe(Recipe recipe) async {
    final i = _recipes.indexWhere((r) => r.id == recipe.id);
    if (i != -1) {
      _recipes[i] = recipe;
      await _storage.saveRecipes(_recipes);
      _onChanged();
    }
  }

  Future<void> removeRecipe(String id) async {
    _recipes.removeWhere((r) => r.id == id);
    await _storage.saveRecipes(_recipes);
    _onChanged();
  }

  // Custom Foods
  Future<void> addCustomFood(FoodItem food) async {
    if (_customFoods.any((f) => f.id == food.id)) return;
    _customFoods.insert(0, food);
    await _storage.saveCustomFoods(_customFoods);
    _onChanged();
  }

  Future<void> removeCustomFood(String id) async {
    _customFoods.removeWhere((f) => f.id == id);
    await _storage.saveCustomFoods(_customFoods);
    _onChanged();
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
    _favoriteFoods.insert(0, food.copyWith(isFavorite: true));
    _favoriteFoodIds.add(food.id);
    await _storage.saveFavoriteFoods(_favoriteFoods);
    _onChanged();
  }

  Future<void> removeFavorite(String id) async {
    _favoriteFoods.removeWhere((f) => f.id == id);
    _favoriteFoodIds.remove(id);
    await _storage.saveFavoriteFoods(_favoriteFoods);
    _onChanged();
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
    _customPortions.add(portion);
    await _storage.saveCustomPortions(_customPortions);
    _onChanged();
  }

  Future<void> removeCustomPortion(String id) async {
    _customPortions.removeWhere((p) => p.id == id);
    await _storage.saveCustomPortions(_customPortions);
    _onChanged();
  }

  void clearAll() {
    _recipes = [];
    _customFoods = [];
    _favoriteFoods = [];
    _favoriteFoodIds = {};
    _customPortions = [];
  }
}
