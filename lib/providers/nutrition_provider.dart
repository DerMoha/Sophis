import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/nutrition_totals.dart';
import 'package:sophis/models/user_profile.dart';
import 'package:sophis/models/water_entry.dart';
import 'package:sophis/models/weight_entry.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/models/meal_plan.dart';
import 'package:sophis/models/custom_portion.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/workout_entry.dart';
import 'package:sophis/models/user_stats.dart';
import 'package:sophis/services/storage_service.dart';
import 'package:sophis/services/health_service.dart';
import 'package:sophis/services/database_service.dart';
import 'package:sophis/services/home_widget_service.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/services/nutrition/food_log_controller.dart';
import 'package:sophis/services/nutrition/hydration_controller.dart';
import 'package:sophis/services/nutrition/workout_controller.dart';
import 'package:sophis/services/nutrition/meal_plan_controller.dart';
import 'package:sophis/services/nutrition/food_library_controller.dart';
import 'package:sophis/services/nutrition/nutrition_persistence.dart';
import 'package:sophis/services/nutrition/nutrition_store.dart';
import 'package:sophis/services/progress_photo_controller.dart';
import 'package:sophis/models/progress_photo.dart';
import 'package:sophis/models/nutrition_backup.dart';
import 'package:uuid/uuid.dart';

/// Central state management for nutrition tracking.
///
/// Delegates domain logic to focused controllers while maintaining the public
/// API surface for backward compatibility. Also handles cross-cutting concerns
/// like goals, profile, user stats, health sync, and cache date management.
class NutritionProvider extends ChangeNotifier {
  final StorageService _storage;
  final DatabaseService _db;

  late final FoodLogController _foodLog;
  late final HydrationController _hydration;
  late final WorkoutController _workouts;
  late final MealPlanController _mealPlan;
  late final FoodLibraryController _foodLibrary;
  late final ProgressPhotoController _progressPhotos;
  late final NutritionPersistence _persistence;
  late final NutritionStore _store;

  NutritionGoals? _goals;
  UserProfile? _profile;
  List<WeightEntry> _weightEntries = [];
  List<ProgressPhoto> _photos = [];
  UserStats _userStats = const UserStats();

  double _healthSyncBurnedCalories = 0.0;
  final HealthServiceProtocol _healthService;
  final bool _cleanupProgressPhotosOnLoad;
  SettingsProvider? _settingsProvider;

  bool _isLoading = true;
  bool get isLoading => _isLoading;
  DatabaseService get databaseService => _db;
  NutritionStore get store => _store;

  // Shared cache date tracking (used by food log, hydration, workout controllers)
  DateTime? _cacheDate;

  NutritionProvider(
    this._storage,
    this._db, {
    HealthServiceProtocol? healthService,
    bool cleanupProgressPhotosOnLoad = true,
  })  : _healthService = healthService ?? HealthService(),
        _cleanupProgressPhotosOnLoad = cleanupProgressPhotosOnLoad {
    _persistence = NutritionPersistence(_db, _storage);
    _store = NutritionStore(
      _db,
      _storage,
      persistence: _persistence,
    );
    _foodLog = FoodLogController(
      _db,
      _onFoodChanged,
      _isCacheValid,
      _currentCacheDate,
      store: _store,
    );
    _hydration = HydrationController(
      _db,
      _onSimpleChanged,
      _isCacheValid,
      _currentCacheDate,
      store: _store,
    );
    _workouts = WorkoutController(
      _db,
      _onSimpleChanged,
      _isCacheValid,
      _currentCacheDate,
      store: _store,
    );
    _mealPlan = MealPlanController(
      _persistence,
      _onSimpleChanged,
      _dayKey,
      store: _store,
    );
    _foodLibrary = FoodLibraryController(
      _persistence,
      _onSimpleChanged,
      store: _store,
    );
    _progressPhotos = ProgressPhotoController(_db);
  }

  Future<void> initialize() => _loadData();

  // ── Cache date helpers (shared across controllers) ──────────────────────

  bool _isCacheValid() {
    if (_cacheDate == null) return false;
    final now = DateTime.now();
    return _cacheDate!.year == now.year &&
        _cacheDate!.month == now.month &&
        _cacheDate!.day == now.day;
  }

  DateTime _currentCacheDate() {
    if (!_isCacheValid()) {
      _prepareTodayCache();
    }
    return _cacheDate!;
  }

  void _prepareTodayCache() {
    if (_isCacheValid()) return;
    _cacheDate = DateTime.now();
  }

  int _dayKey(DateTime date) => date.year * 10000 + date.month * 100 + date.day;

  /// Called by food log controller when food entries change.
  /// Triggers streak update and home widget refresh.
  Future<void> _onFoodChanged() async {
    await _updateStreak();
    await _persistence.saveRecentFoods(
      _foodLog.recentFoods,
      _foodLog.recentFoodMeals,
    );
    HomeWidgetService.updateWidgetData(this);
    notifyListeners();
  }

  /// Called by other controllers for simple change notification.
  Future<void> _onSimpleChanged() async {
    HomeWidgetService.updateWidgetData(this);
    notifyListeners();
  }

  // ── Public API: Getters ─────────────────────────────────────────────────

  NutritionGoals? get goals => _goals;
  UserProfile? get profile => _profile;
  List<FoodEntry> get entries => _foodLog.entries;
  List<WaterEntry> get waterEntries => _hydration.waterEntries;
  List<WeightEntry> get weightEntries => _weightEntries;
  List<Recipe> get recipes => _foodLibrary.recipes;
  List<PlannedMeal> get plannedMeals => _mealPlan.plannedMeals;
  Set<String> get shoppingListChecked => _mealPlan.shoppingListChecked;
  List<CustomPortion> get customPortions => _foodLibrary.customPortions;
  List<FoodItem> get recentFoods => _foodLog.recentFoods;
  List<WorkoutEntry> get workoutEntries => _workouts.workoutEntries;
  List<FoodItem> get customFoods => _foodLibrary.customFoods;
  List<FoodItem> get favoriteFoods => _foodLibrary.favoriteFoods;
  UserStats get userStats => _userStats;
  List<ProgressPhoto> get photos => _photos;

  double get burnedCalories =>
      _workouts.getTodayWorkoutCalories() + _healthSyncBurnedCalories;
  StorageService get storage => _storage;

  void attachSettingsProvider(SettingsProvider settings) {
    _settingsProvider = settings;
  }

  // ── Load / Reload ───────────────────────────────────────────────────────

  Future<void> reloadAll() async {
    await _loadData();
  }

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    await _migrateToDbIfNeeded();
    final persistentState = await _persistence.initialize();

    final foods = await _db.getAllFoods();
    final water = await _db.getAllWater();
    final weights = await _db.getAllWeights();
    final workouts = await _db.getAllWorkouts();

    _foodLog.loadData(
      foods,
      persistentState.recentFoods,
      persistentState.recentFoodMeals,
    );
    _hydration.loadData(water);
    weights.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _weightEntries = weights;
    _workouts.loadData(workouts);

    _goals = _storage.loadGoals();
    _profile = _storage.loadProfile();

    _foodLibrary.loadData(
      recipes: persistentState.recipes,
      customFoods: persistentState.customFoods,
      favoriteFoods: persistentState.favoriteFoods,
      customPortions: persistentState.customPortions,
    );

    _mealPlan.loadData(
      persistentState.plannedMeals,
      persistentState.shoppingListChecked,
    );

    _userStats = persistentState.userStats;

    final photos = await _db.getAllPhotos();
    _photos = photos;

    if (_cleanupProgressPhotosOnLoad) {
      // Clean up orphaned photo files in background.
      _progressPhotos.cleanupOrphanedFiles();
    }

    _cacheDate = null; // Force cache rebuild
    HomeWidgetService.updateWidgetData(this);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _migrateToDbIfNeeded() async {
    if (!_storage.isMigrationComplete()) {
      await _migrateV1Data();
    } else {
      try {
        await _storage.clearLegacyMigratedData();
      } catch (e) {
        debugPrint('Failed to clear legacy v1 data: $e');
      }
    }

    await _migrateV2Data();
  }

  Future<void> _migrateV1Data() async {
    final legacyFoods = _storage.loadFoodEntries();
    final legacyWater = _storage.loadWaterEntries();
    final legacyWeights = _storage.loadWeightEntries();
    final legacyWorkouts = _storage.loadWorkoutEntries();

    try {
      if (legacyFoods.isNotEmpty) await _db.insertFoods(legacyFoods);
      if (legacyWater.isNotEmpty) await _db.insertWaterList(legacyWater);
      if (legacyWeights.isNotEmpty) await _db.insertWeightList(legacyWeights);
      if (legacyWorkouts.isNotEmpty) {
        await _db.insertWorkoutList(legacyWorkouts);
      }

      await _storage.setMigrationComplete();
      await _storage.clearLegacyMigratedData();
    } catch (e) {
      debugPrint('Database migration failed, will retry on next app start: $e');
    }
  }

  Future<void> _migrateV2Data() async {
    if (_storage.isMigrationV2Complete()) {
      return;
    }

    try {
      final legacyRecipes = _storage.loadRecipes();
      final legacyCustomFoods = _storage.loadCustomFoods();
      final legacyFavoriteFoods = _storage.loadFavoriteFoods();
      final legacyPlannedMeals = _storage.loadPlannedMeals();
      final legacyCustomPortions = _storage.loadCustomPortions();
      final legacyRecentFoods = _storage.loadRecentFoods();
      final legacyUserStats = _storage.loadUserStats();
      final legacyShoppingChecked = _storage.loadShoppingListChecked();

      await _migrateMissingRecipes(legacyRecipes);
      await _migrateMissingCustomFoods(legacyCustomFoods);
      await _migrateMissingFavoriteFoods(legacyFavoriteFoods);
      await _migrateMissingPlannedMeals(legacyPlannedMeals);
      await _migrateMissingCustomPortions(legacyCustomPortions);
      if (legacyRecentFoods.isNotEmpty) {
        await _db.migrateRecentFoods(legacyRecentFoods);
      }
      await _db.migrateUserStats(legacyUserStats);
      await _db.migratePlannedMealsChecked(legacyShoppingChecked);

      await _storage.setMigrationV2Complete();
    } catch (e) {
      debugPrint(
        'Database v2 migration failed, will retry on next app start: $e',
      );
    }
  }

  Future<void> _migrateMissingRecipes(List<Recipe> legacyRecipes) async {
    if (legacyRecipes.isEmpty) return;

    final existingIds = (await _db.getAllRecipes()).map((recipe) => recipe.id);
    final recipes = _onlyMissingById(
      legacyRecipes,
      existingIds,
      (recipe) => recipe.id,
    );
    if (recipes.isNotEmpty) await _db.migrateRecipes(recipes);
  }

  Future<void> _migrateMissingCustomFoods(List<FoodItem> legacyFoods) async {
    if (legacyFoods.isEmpty) return;

    final existingIds = (await _db.getAllCustomFoods()).map((food) => food.id);
    final foods = _onlyMissingById(legacyFoods, existingIds, (food) => food.id);
    if (foods.isNotEmpty) await _db.migrateCustomFoods(foods);
  }

  Future<void> _migrateMissingFavoriteFoods(List<FoodItem> legacyFoods) async {
    if (legacyFoods.isEmpty) return;

    final existingIds =
        (await _db.getAllFavoriteFoods()).map((food) => food.id);
    final foods = _onlyMissingById(legacyFoods, existingIds, (food) => food.id);
    if (foods.isNotEmpty) await _db.migrateFavoriteFoods(foods);
  }

  Future<void> _migrateMissingPlannedMeals(
    List<PlannedMeal> legacyMeals,
  ) async {
    if (legacyMeals.isEmpty) return;

    final existingIds = (await _db.getAllPlannedMeals()).map((meal) => meal.id);
    final meals = _onlyMissingById(legacyMeals, existingIds, (meal) => meal.id);
    if (meals.isNotEmpty) await _db.migratePlannedMeals(meals);
  }

  Future<void> _migrateMissingCustomPortions(
    List<CustomPortion> legacyPortions,
  ) async {
    if (legacyPortions.isEmpty) return;

    final existingIds =
        (await _db.getAllCustomPortions()).map((portion) => portion.id);
    final portions = _onlyMissingById(
      legacyPortions,
      existingIds,
      (portion) => portion.id,
    );
    if (portions.isNotEmpty) await _db.migrateCustomPortions(portions);
  }

  List<T> _onlyMissingById<T>(
    Iterable<T> values,
    Iterable<String> existingIds,
    String Function(T) idOf,
  ) {
    final ids = existingIds.toSet();
    final missing = <T>[];
    for (final value in values) {
      if (ids.add(idOf(value))) missing.add(value);
    }
    return missing;
  }

  // ── Goals & Profile ────────────────────────────────────────────────────

  Future<void> setGoals(NutritionGoals goals) async {
    await _store.commitOrThrow(SaveGoals(goals));
    _goals = goals;
    HomeWidgetService.updateWidgetData(this);
    notifyListeners();
  }

  Future<void> setProfile(UserProfile profile) async {
    await _store.commitOrThrow(SaveProfile(profile));
    _profile = profile;
    notifyListeners();
  }

  // ── Food Entries ────────────────────────────────────────────────────────

  Future<void> addFoodEntry(FoodEntry entry) async {
    await _foodLog.addFoodEntry(entry);
    await _syncNutritionForDate(entry.timestamp);
  }

  Future<void> removeFoodEntry(String id) async {
    final entry = _foodLog.entries.where((e) => e.id == id).firstOrNull;
    await _foodLog.removeFoodEntry(id);
    if (entry != null) await _syncNutritionForDate(entry.timestamp);
  }

  Future<void> updateFoodEntry(FoodEntry entry) async {
    await _foodLog.updateFoodEntry(entry);
    await _syncNutritionForDate(entry.timestamp);
  }

  Future<void> _syncNutritionForDate(DateTime date) async {
    if (_settingsProvider?.healthNutritionSyncEnabled != true) return;
    final totals = getTotalsForDate(date);
    await _healthService.writeNutritionForDay(
      date,
      calories: totals.calories,
      protein: totals.protein,
      carbs: totals.carbs,
      fat: totals.fat,
      fiber: totals.fiber,
    );
  }

  Future<void> duplicateFoodEntry(FoodEntry entry, {String? toMeal}) =>
      _foodLog.duplicateFoodEntry(entry, toMeal: toMeal);

  List<FoodEntry> getTodayEntries() => _foodLog.getTodayEntries();

  List<FoodEntry> getEntriesForDate(DateTime date) =>
      _foodLog.getEntriesForDate(date);

  List<FoodEntry> getEntriesByMeal(String meal) =>
      _foodLog.getEntriesByMeal(meal);

  NutritionTotals getTodayTotals() => _foodLog.getTodayTotals();

  NutritionTotals getTotalsForDate(DateTime date) =>
      _foodLog.getTotalsForDate(date);

  double getRemainingCalories() {
    if (_goals == null) return 0;
    return _goals!.calories - getTodayTotals().calories + burnedCalories;
  }

  // ── Health Sync ─────────────────────────────────────────────────────────

  Future<void> refreshBurnedCalories({bool enabled = true}) async {
    if (!enabled) {
      _healthSyncBurnedCalories = 0.0;
      notifyListeners();
      return;
    }

    try {
      _healthSyncBurnedCalories = await _healthService.getTodayBurnedCalories();
      notifyListeners();
    } catch (e) {
      debugPrint('Health sync failed: $e');
    }
  }

  // ── Workouts ────────────────────────────────────────────────────────────

  Future<void> addWorkoutEntry(double calories, {String? note}) =>
      _workouts.addWorkoutEntry(calories, note: note);

  Future<void> restoreWorkoutEntry(WorkoutEntry entry) =>
      _workouts.restoreWorkoutEntry(entry);

  Future<void> updateWorkoutEntry(WorkoutEntry entry) =>
      _workouts.updateWorkoutEntry(entry);

  Future<void> removeWorkoutEntry(String id) =>
      _workouts.removeWorkoutEntry(id);

  double getTodayWorkoutCalories() => _workouts.getTodayWorkoutCalories();

  List<WorkoutEntry> getTodayWorkoutEntries() =>
      _workouts.getTodayWorkoutEntries();

  // ── Water ───────────────────────────────────────────────────────────────

  Future<void> addWater(double ml) => _hydration.addWater(ml);

  Future<void> restoreWaterEntry(WaterEntry entry) =>
      _hydration.restoreWaterEntry(entry);

  Future<void> removeWaterEntry(String id) => _hydration.removeWaterEntry(id);

  double getTodayWaterTotal() => _hydration.getTodayWaterTotal();

  List<WaterEntry> getTodayWaterEntries() => _hydration.getTodayWaterEntries();

  // ── Weight ──────────────────────────────────────────────────────────────

  Future<void> addWeight(double kg, {String? note}) async {
    final entry = WeightEntry(
      id: const Uuid().v4(),
      weightKg: kg,
      timestamp: DateTime.now(),
      note: note,
      source: 'manual',
    );
    await restoreWeightEntry(entry);

    if (_settingsProvider?.healthWeightSyncEnabled == true &&
        entry.source == 'manual') {
      await _healthService.writeWeight(kg, entry.timestamp);
    }
  }

  Future<void> restoreWeightEntry(WeightEntry entry) async {
    await _store.commitOrThrow(SaveWeightEntry(entry));
    _weightEntries.add(entry);
    _weightEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();
  }

  Future<void> removeWeightEntry(String id) async {
    final index = _weightEntries.indexWhere((entry) => entry.id == id);
    if (index == -1) return;

    await _store.commitOrThrow(DeleteWeightEntry(id));
    _weightEntries.removeAt(index);
    notifyListeners();
  }

  /// Pulls weight entries from Apple Health for the last 30 days and inserts
  /// any that are not already recorded in Sophis (deduplicated within 60s).
  Future<void> syncWeightFromHealth() async {
    try {
      final end = DateTime.now();
      final start = end.subtract(const Duration(days: 30));
      final healthEntries = await _healthService.getWeightEntries(start, end);

      for (final he in healthEntries) {
        final alreadyExists = _weightEntries.any(
          (e) => (e.timestamp.difference(he.timestamp).inSeconds).abs() <= 60,
        );
        if (!alreadyExists) {
          final entry = WeightEntry(
            id: const Uuid().v4(),
            weightKg: he.kg,
            timestamp: he.timestamp,
            source: 'health',
          );
          await _store.commitOrThrow(SaveWeightEntry(entry));
          _weightEntries.add(entry);
        }
      }

      _weightEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();
    } catch (e) {
      debugPrint('Weight sync from Health failed: $e');
    }
  }

  WeightEntry? get latestWeight =>
      _weightEntries.isEmpty ? null : _weightEntries.first;

  // ── Progress Photos ─────────────────────────────────────────────────────

  Future<void> addProgressPhoto({
    required File imageFile,
    DateTime? timestamp,
    double? weightKg,
    String? note,
    PhotoCategory category = PhotoCategory.front,
  }) async {
    final photo = await _progressPhotos.addPhoto(
      imageFile: imageFile,
      timestamp: timestamp,
      weightKg: weightKg ?? latestWeight?.weightKg,
      note: note,
      category: category,
    );
    _photos.add(photo);
    _photos.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();
  }

  Future<void> deleteProgressPhoto(String id) async {
    await _progressPhotos.deletePhoto(id);
    _photos.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  Future<void> restoreProgressPhoto(ProgressPhoto photo) async {
    await _db.insertPhoto(photo);
    _photos.add(photo);
    _photos.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();
  }

  NutritionBackup createBackup() => NutritionBackup(
        goals: _goals,
        profile: _profile,
        foodEntries: List.unmodifiable(entries),
        waterEntries: List.unmodifiable(waterEntries),
        weightEntries: List.unmodifiable(_weightEntries),
        workoutEntries: List.unmodifiable(workoutEntries),
        recipes: List.unmodifiable(recipes),
        plannedMeals: List.unmodifiable(plannedMeals),
        customFoods: List.unmodifiable(customFoods),
        favoriteFoods: List.unmodifiable(favoriteFoods),
        customPortions: List.unmodifiable(customPortions),
        recentFoods: List.unmodifiable(recentFoods),
        recentFoodMeals: Map.unmodifiable(_foodLog.recentFoodMeals),
        userStats: _userStats,
        shoppingListChecked: Set.unmodifiable(shoppingListChecked),
        progressPhotos: List.unmodifiable(_photos),
      );

  Future<ProgressPhoto> stageBackupPhoto(
    ProgressPhoto metadata,
    List<int> imageBytes, {
    List<int>? thumbnailBytes,
  }) {
    return _progressPhotos.stageBackupPhoto(
      metadata,
      imageBytes,
      thumbnailBytes: thumbnailBytes,
    );
  }

  Future<void> clearProgressPhotoFilesForRestore() =>
      _progressPhotos.deleteAllPhotoFiles();

  Future<void> replaceFromBackup(NutritionBackup backup) async {
    await _storage.clearNutritionData();

    await _db.transaction(() async {
      await _db.deleteNutritionData();
      await _db.insertFoods(backup.foodEntries);
      await _db.insertWaterList(backup.waterEntries);
      await _db.insertWeightList(backup.weightEntries);
      await _db.insertWorkoutList(backup.workoutEntries);
      await _db.insertPhotos(backup.progressPhotos);
      await _persistence.saveRecipes(backup.recipes);
      await _persistence.saveCustomFoods(backup.customFoods);
      await _persistence.saveFavoriteFoods(backup.favoriteFoods);
      await _persistence.savePlannedMeals(backup.plannedMeals);
      await _persistence.saveCustomPortions(backup.customPortions);
      await _persistence.saveRecentFoods(
        backup.recentFoods,
        backup.recentFoodMeals,
      );
      await _persistence.saveUserStats(backup.userStats);
      await _persistence.saveShoppingListChecked(backup.shoppingListChecked);
    });

    if (backup.goals != null) await _storage.saveGoals(backup.goals!);
    if (backup.profile != null) await _storage.saveProfile(backup.profile!);
    await _loadData();
  }

  // ── Recipes ─────────────────────────────────────────────────────────────

  Future<void> addRecipe(Recipe recipe) => _foodLibrary.addRecipe(recipe);

  Future<void> updateRecipe(Recipe recipe) => _foodLibrary.updateRecipe(recipe);

  Future<void> removeRecipe(String id) => _foodLibrary.removeRecipe(id);

  Future<void> addRecipeAsMeal(Recipe recipe, int servings, String meal) async {
    final nutrients = recipe.nutrientsPerServing;
    final entry = FoodEntry(
      id: const Uuid().v4(),
      name: '${recipe.name} (${servings}x)',
      calories: nutrients.calories * servings,
      protein: nutrients.protein * servings,
      carbs: nutrients.carbs * servings,
      fat: nutrients.fat * servings,
      fiber: nutrients.fiber * servings,
      timestamp: DateTime.now(),
      meal: meal,
    );
    await addFoodEntry(entry);
  }

  // ── Meal Planning ───────────────────────────────────────────────────────

  Future<void> addPlannedMeal(PlannedMeal meal) =>
      _mealPlan.addPlannedMeal(meal);

  Future<void> removePlannedMeal(String id) => _mealPlan.removePlannedMeal(id);

  Future<void> updatePlannedMeal(PlannedMeal meal) =>
      _mealPlan.updatePlannedMeal(meal);

  List<PlannedMeal> getPlannedMealsForDate(DateTime date) =>
      _mealPlan.getPlannedMealsForDate(date);

  bool hasPlannedMealsForDate(DateTime date) =>
      _mealPlan.hasPlannedMealsForDate(date);

  List<PlannedMeal> getPlannedMealsForRange(DateTime start, DateTime end) =>
      _mealPlan.getPlannedMealsForRange(start, end);

  List<PlannedMeal> getPlannedMealsByType(DateTime date, String meal) =>
      _mealPlan.getPlannedMealsByType(date, meal);

  NutritionTotals getPlannedTotalsForDate(DateTime date) =>
      _mealPlan.getPlannedTotalsForDate(date);

  Future<void> copyPlannedMealToDate(PlannedMeal meal, DateTime newDate) =>
      _mealPlan.copyPlannedMealToDate(meal, newDate);

  Future<void> copyDayMeals(DateTime from, DateTime to) =>
      _mealPlan.copyDayMeals(from, to);

  Future<void> logPlannedMeal(PlannedMeal planned) async {
    final entry = FoodEntry(
      id: const Uuid().v4(),
      name: planned.name,
      calories: planned.calories,
      protein: planned.protein,
      carbs: planned.carbs,
      fat: planned.fat,
      fiber: planned.fiber,
      timestamp: DateTime.now(),
      meal: planned.meal,
    );
    await addFoodEntry(entry);
  }

  // ── Shopping List ───────────────────────────────────────────────────────

  List<ShoppingListItem> generateShoppingList(DateTime start, DateTime end) =>
      _mealPlan.generateShoppingList(start, end);

  Future<void> toggleShoppingItem(String name, String unit) =>
      _mealPlan.toggleShoppingItem(name, unit);

  Future<void> clearCheckedShoppingItems() =>
      _mealPlan.clearCheckedShoppingItems();

  bool isShoppingItemChecked(String name, String unit) =>
      _mealPlan.isShoppingItemChecked(name, unit);

  // ── Custom Portions ─────────────────────────────────────────────────────

  List<CustomPortion> getCustomPortionsForProduct(String productKey) =>
      _foodLibrary.getCustomPortionsForProduct(productKey);

  Future<void> addCustomPortion(CustomPortion portion) =>
      _foodLibrary.addCustomPortion(portion);

  Future<void> removeCustomPortion(String id) =>
      _foodLibrary.removeCustomPortion(id);

  // ── Recent Foods ────────────────────────────────────────────────────────

  List<FoodItem> getRecentFoodsForMeal(String meal) =>
      _foodLog.getRecentFoodsForMeal(meal);

  Future<void> addRecentFood(FoodItem food, {String? meal}) =>
      _foodLog.addRecentFood(food, meal: meal);

  // ── Custom Foods ────────────────────────────────────────────────────────

  Future<void> addCustomFood(FoodItem food) => _foodLibrary.addCustomFood(food);

  Future<void> removeCustomFood(String id) => _foodLibrary.removeCustomFood(id);

  List<FoodItem> searchCustomFoods(String query) =>
      _foodLibrary.searchCustomFoods(query);

  // ── Favorites ───────────────────────────────────────────────────────────

  bool isFavorite(String id) => _foodLibrary.isFavorite(id);

  Future<void> addFavorite(FoodItem food) => _foodLibrary.addFavorite(food);

  Future<void> removeFavorite(String id) => _foodLibrary.removeFavorite(id);

  Future<void> toggleFavorite(FoodItem food) =>
      _foodLibrary.toggleFavorite(food);

  // ── Stats & Achievements ────────────────────────────────────────────────

  Future<void> _updateStreak() async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final lastLog = _userStats.lastLogDate;

    if (lastLog != null) {
      final lastLogDate = DateTime(lastLog.year, lastLog.month, lastLog.day);
      final daysDifference = todayDate.difference(lastLogDate).inDays;

      if (daysDifference == 0) {
        return;
      }
    }

    final nextStats = _nextStatsAfterLog(today, todayDate);
    final withAchievements = _withAchievements(nextStats);
    await _store.commitOrThrow(SaveUserStats(withAchievements));
    _userStats = withAchievements;
  }

  UserStats _nextStatsAfterLog(DateTime now, DateTime today) {
    final lastLog = _userStats.lastLogDate;
    if (lastLog == null) {
      return _userStats.copyWith(
        currentStreak: 1,
        longestStreak: 1,
        lastLogDate: now,
        totalDaysLogged: 1,
      );
    }

    final lastDate = DateTime(lastLog.year, lastLog.month, lastLog.day);
    final daysDifference = today.difference(lastDate).inDays;
    if (daysDifference == 1) {
      final nextStreak = _userStats.currentStreak + 1;
      return _userStats.copyWith(
        currentStreak: nextStreak,
        longestStreak: nextStreak > _userStats.longestStreak
            ? nextStreak
            : _userStats.longestStreak,
        lastLogDate: now,
        totalDaysLogged: _userStats.totalDaysLogged + 1,
      );
    }
    return _userStats.copyWith(
      currentStreak: 1,
      lastLogDate: now,
      totalDaysLogged: _userStats.totalDaysLogged + 1,
    );
  }

  UserStats _withAchievements(UserStats stats) {
    final currentAchievements = List<String>.from(stats.achievements);
    var newAchievements = false;

    if (!currentAchievements.contains(Achievements.firstLog) &&
        stats.totalDaysLogged >= 1) {
      currentAchievements.add(Achievements.firstLog);
      newAchievements = true;
    }

    if (!currentAchievements.contains(Achievements.threeDayStreak) &&
        stats.currentStreak >= 3) {
      currentAchievements.add(Achievements.threeDayStreak);
      newAchievements = true;
    }

    if (!currentAchievements.contains(Achievements.weekWarrior) &&
        stats.currentStreak >= 7) {
      currentAchievements.add(Achievements.weekWarrior);
      newAchievements = true;
    }

    if (!currentAchievements.contains(Achievements.twoWeekStreak) &&
        stats.currentStreak >= 14) {
      currentAchievements.add(Achievements.twoWeekStreak);
      newAchievements = true;
    }

    if (!currentAchievements.contains(Achievements.monthlyMaster) &&
        stats.currentStreak >= 30) {
      currentAchievements.add(Achievements.monthlyMaster);
      newAchievements = true;
    }

    if (!currentAchievements.contains(Achievements.centurion) &&
        stats.totalDaysLogged >= 100) {
      currentAchievements.add(Achievements.centurion);
      newAchievements = true;
    }

    return newAchievements
        ? stats.copyWith(achievements: currentAchievements)
        : stats;
  }

  // ── Clear All ───────────────────────────────────────────────────────────

  Future<void> clearAllData() async {
    _goals = null;
    _profile = null;
    _weightEntries = [];
    _photos = [];
    _userStats = const UserStats();

    _foodLog.clearAll();
    _hydration.clearAll();
    _workouts.clearAll();
    _mealPlan.clearAll();
    _foodLibrary.clearAll();

    _cacheDate = null;
    _healthSyncBurnedCalories = 0.0;

    if (_cleanupProgressPhotosOnLoad) {
      await _progressPhotos.deleteAllPhotoFiles();
    }
    await _db.deleteAllData();
    await _storage.clear();
    HomeWidgetService.updateWidgetData(this);
    notifyListeners();
  }
}
