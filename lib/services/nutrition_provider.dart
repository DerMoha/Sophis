import 'package:flutter/foundation.dart';
import '../models/nutrition_goals.dart';
import '../models/food_entry.dart';
import '../models/user_profile.dart';
import '../models/water_entry.dart';
import '../models/weight_entry.dart';
import '../models/recipe.dart';
import 'storage_service.dart';

/// Central state management for nutrition tracking
class NutritionProvider extends ChangeNotifier {
  final StorageService _storage;

  NutritionGoals? _goals;
  UserProfile? _profile;
  List<FoodEntry> _entries = [];
  List<WaterEntry> _waterEntries = [];
  List<WeightEntry> _weightEntries = [];
  List<Recipe> _recipes = [];

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

  void _loadData() {
    _goals = _storage.loadGoals();
    _profile = _storage.loadProfile();
    _entries = _storage.loadFoodEntries();
    _waterEntries = _storage.loadWaterEntries();
    _weightEntries = _storage.loadWeightEntries();
    _recipes = _storage.loadRecipes();
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
    await _storage.saveFoodEntries(_entries);
    notifyListeners();
  }

  Future<void> removeFoodEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    await _storage.saveFoodEntries(_entries);
    notifyListeners();
  }

  List<FoodEntry> getTodayEntries() {
    final now = DateTime.now();
    return _entries.where((e) =>
      e.timestamp.year == now.year &&
      e.timestamp.month == now.month &&
      e.timestamp.day == now.day
    ).toList();
  }

  List<FoodEntry> getEntriesForDate(DateTime date) {
    return _entries.where((e) =>
      e.timestamp.year == date.year &&
      e.timestamp.month == date.month &&
      e.timestamp.day == date.day
    ).toList();
  }

  List<FoodEntry> getEntriesByMeal(String meal) {
    return getTodayEntries().where((e) => e.meal == meal).toList();
  }

  Map<String, double> getTodayTotals() {
    final today = getTodayEntries();
    double cal = 0, prot = 0, carb = 0, fat = 0;
    for (final e in today) {
      cal += e.calories;
      prot += e.protein;
      carb += e.carbs;
      fat += e.fat;
    }
    return {'calories': cal, 'protein': prot, 'carbs': carb, 'fat': fat};
  }

  double getRemainingCalories() {
    if (_goals == null) return 0;
    return _goals!.calories - getTodayTotals()['calories']!;
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

  // Clear all
  Future<void> clearAllData() async {
    _goals = null;
    _profile = null;
    _entries = [];
    _waterEntries = [];
    _weightEntries = [];
    _recipes = [];
    await _storage.clear();
    notifyListeners();
  }
}
