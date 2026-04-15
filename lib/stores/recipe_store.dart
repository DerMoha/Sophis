import 'package:flutter/foundation.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/models/custom_portion.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/services/storage_service.dart';

class RecipeStore extends ChangeNotifier {
  final StorageService _storage;

  List<Recipe> _recipes = [];
  List<FoodItem> _customFoods = [];
  List<FoodItem> _favoriteFoods = [];
  Set<String> _favoriteFoodIds = {};
  List<CustomPortion> _customPortions = [];

  RecipeStore(this._storage);

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
    notifyListeners();
  }

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

  Future<void> addCustomFood(FoodItem food) async {
    if (_customFoods.any((f) => f.id == food.id)) return;
    _customFoods.insert(0, food);
    await _storage.saveCustomFoods(_customFoods);
    notifyListeners();
  }

  Future<void> removeCustomFood(String id) async {
    _customFoods.removeWhere((f) => f.id == id);
    await _storage.saveCustomFoods(_customFoods);
    notifyListeners();
  }

  List<FoodItem> searchCustomFoods(String query) {
    if (query.isEmpty) return _customFoods;
    final lowerQuery = query.toLowerCase();
    return _customFoods
        .where((f) => f.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  bool isFavorite(String id) => _favoriteFoodIds.contains(id);

  Future<void> addFavorite(FoodItem food) async {
    if (isFavorite(food.id)) return;
    _favoriteFoods.insert(0, food.copyWith(isFavorite: true));
    _favoriteFoodIds.add(food.id);
    await _storage.saveFavoriteFoods(_favoriteFoods);
    notifyListeners();
  }

  Future<void> removeFavorite(String id) async {
    _favoriteFoods.removeWhere((f) => f.id == id);
    _favoriteFoodIds.remove(id);
    await _storage.saveFavoriteFoods(_favoriteFoods);
    notifyListeners();
  }

  Future<void> toggleFavorite(FoodItem food) async {
    if (isFavorite(food.id)) {
      await removeFavorite(food.id);
    } else {
      await addFavorite(food);
    }
  }

  List<CustomPortion> getCustomPortionsForProduct(String productKey) {
    return _customPortions.where((p) => p.productKey == productKey).toList();
  }

  Future<void> addCustomPortion(CustomPortion portion) async {
    _customPortions.add(portion);
    await _storage.saveCustomPortions(_customPortions);
    notifyListeners();
  }

  Future<void> removeCustomPortion(String id) async {
    _customPortions.removeWhere((p) => p.id == id);
    await _storage.saveCustomPortions(_customPortions);
    notifyListeners();
  }

  void clearAll() {
    _recipes = [];
    _customFoods = [];
    _favoriteFoods = [];
    _favoriteFoodIds = {};
    _customPortions = [];
  }
}
