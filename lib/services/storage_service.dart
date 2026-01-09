import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/nutrition_goals.dart';
import '../models/food_entry.dart';
import '../models/user_profile.dart';
import '../models/water_entry.dart';
import '../models/weight_entry.dart';
import '../models/recipe.dart';
import '../models/app_settings.dart';
import '../models/meal_plan.dart';
import '../models/custom_portion.dart';
import '../models/food_item.dart';

/// Local storage service using SharedPreferences
class StorageService {
  static const _goalsKey = 'nutrition_goals';
  static const _entriesKey = 'food_entries';
  static const _profileKey = 'user_profile';
  static const _waterEntriesKey = 'water_entries';
  static const _weightEntriesKey = 'weight_entries';
  static const _recipesKey = 'recipes';
  static const _settingsKey = 'app_settings';
  static const _apiKeyStorageKey = 'gemini_api_key';
  static const _plannedMealsKey = 'planned_meals';
  static const _shoppingListKey = 'shopping_list_checked';
  static const _customPortionsKey = 'custom_portions';
  static const _recentFoodsKey = 'recent_foods';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  StorageService(this._prefs, this._secureStorage);

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage();
    return StorageService(prefs, secureStorage);
  }

  // Goals
  Future<void> saveGoals(NutritionGoals goals) async {
    await _prefs.setString(_goalsKey, jsonEncode(goals.toJson()));
  }

  NutritionGoals? loadGoals() {
    final json = _prefs.getString(_goalsKey);
    if (json == null) return null;
    return NutritionGoals.fromJson(jsonDecode(json));
  }

  // Profile
  Future<void> saveProfile(UserProfile profile) async {
    await _prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  UserProfile? loadProfile() {
    final json = _prefs.getString(_profileKey);
    if (json == null) return null;
    return UserProfile.fromJson(jsonDecode(json));
  }

  // Food Entries
  Future<void> saveFoodEntries(List<FoodEntry> entries) async {
    final list = entries.map((e) => e.toJson()).toList();
    await _prefs.setString(_entriesKey, jsonEncode(list));
  }

  List<FoodEntry> loadFoodEntries() {
    final json = _prefs.getString(_entriesKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => FoodEntry.fromJson(e)).toList();
  }

  // Water Entries
  Future<void> saveWaterEntries(List<WaterEntry> entries) async {
    final list = entries.map((e) => e.toJson()).toList();
    await _prefs.setString(_waterEntriesKey, jsonEncode(list));
  }

  List<WaterEntry> loadWaterEntries() {
    final json = _prefs.getString(_waterEntriesKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => WaterEntry.fromJson(e)).toList();
  }

  // Weight Entries
  Future<void> saveWeightEntries(List<WeightEntry> entries) async {
    final list = entries.map((e) => e.toJson()).toList();
    await _prefs.setString(_weightEntriesKey, jsonEncode(list));
  }

  List<WeightEntry> loadWeightEntries() {
    final json = _prefs.getString(_weightEntriesKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => WeightEntry.fromJson(e)).toList();
  }

  // Recipes
  Future<void> saveRecipes(List<Recipe> recipes) async {
    final list = recipes.map((r) => r.toJson()).toList();
    await _prefs.setString(_recipesKey, jsonEncode(list));
  }

  List<Recipe> loadRecipes() {
    final json = _prefs.getString(_recipesKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((r) => Recipe.fromJson(r)).toList();
  }

  // Settings
  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  AppSettings loadSettings() {
    final json = _prefs.getString(_settingsKey);
    if (json == null) return const AppSettings();
    return AppSettings.fromJson(jsonDecode(json));
  }

  // Planned Meals
  Future<void> savePlannedMeals(List<PlannedMeal> meals) async {
    final list = meals.map((m) => m.toJson()).toList();
    await _prefs.setString(_plannedMealsKey, jsonEncode(list));
  }

  List<PlannedMeal> loadPlannedMeals() {
    final json = _prefs.getString(_plannedMealsKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((m) => PlannedMeal.fromJson(m)).toList();
  }

  // Shopping List Checked Items (store just the names of checked items)
  Future<void> saveShoppingListChecked(Set<String> checkedItems) async {
    await _prefs.setStringList(_shoppingListKey, checkedItems.toList());
  }

  Set<String> loadShoppingListChecked() {
    final list = _prefs.getStringList(_shoppingListKey);
    return list?.toSet() ?? {};
  }

  // Custom Portions
  Future<void> saveCustomPortions(List<CustomPortion> portions) async {
    final list = portions.map((p) => p.toJson()).toList();
    await _prefs.setString(_customPortionsKey, jsonEncode(list));
  }

  List<CustomPortion> loadCustomPortions() {
    final json = _prefs.getString(_customPortionsKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((p) => CustomPortion.fromJson(p)).toList();
  }

  // Recent Foods
  static const _maxRecentFoods = 20;

  Future<void> saveRecentFoods(List<FoodItem> foods) async {
    final list = foods.take(_maxRecentFoods).map((f) => f.toJson()).toList();
    await _prefs.setString(_recentFoodsKey, jsonEncode(list));
  }

  List<FoodItem> loadRecentFoods() {
    final json = _prefs.getString(_recentFoodsKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((f) => FoodItem.fromJson(f)).toList();
  }

  // Clear all data
  Future<void> clear() async {
    await _prefs.clear();
    await _secureStorage.deleteAll();
  }

  // Secure API Key Storage
  Future<void> saveApiKey(String? key) async {
    if (key == null || key.isEmpty) {
      await _secureStorage.delete(key: _apiKeyStorageKey);
    } else {
      await _secureStorage.write(key: _apiKeyStorageKey, value: key);
    }
  }

  Future<String?> loadApiKey() async {
    return await _secureStorage.read(key: _apiKeyStorageKey);
  }
}
