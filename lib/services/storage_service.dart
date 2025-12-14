import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/nutrition_goals.dart';
import '../models/food_entry.dart';
import '../models/user_profile.dart';
import '../models/water_entry.dart';
import '../models/weight_entry.dart';
import '../models/recipe.dart';
import '../models/app_settings.dart';

/// Local storage service using SharedPreferences
class StorageService {
  static const _goalsKey = 'nutrition_goals';
  static const _entriesKey = 'food_entries';
  static const _profileKey = 'user_profile';
  static const _waterEntriesKey = 'water_entries';
  static const _weightEntriesKey = 'weight_entries';
  static const _recipesKey = 'recipes';
  static const _settingsKey = 'app_settings';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
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

  // Clear all data
  Future<void> clear() async {
    await _prefs.clear();
  }
}
