import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sophis/models/custom_portion.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/meal_plan.dart';
import 'package:sophis/models/nutrition_backup.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/models/supplement.dart';
import 'package:sophis/models/supplement_log.dart';
import 'package:sophis/models/user_profile.dart';
import 'package:sophis/models/user_stats.dart';
import 'package:sophis/models/water_entry.dart';
import 'package:sophis/models/weight_entry.dart';
import 'package:sophis/models/workout_entry.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/progress_photo.dart';
import 'package:sophis/services/database_service.dart';
import 'package:sophis/services/nutrition/nutrition_persistence.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/storage_service.dart';
import 'package:uuid/uuid.dart';

/// The single application-facing persistence module for user-owned nutrition
/// state. Drift rows, JSON documents, migrations, and write serialization stay
/// behind this seam.
final class NutritionStore {
  final DatabaseService _database;
  final StorageService _storage;
  final NutritionPersistence _persistence;
  final StreamController<ServiceResult<NutritionSnapshot>> _changes =
      StreamController<ServiceResult<NutritionSnapshot>>.broadcast(sync: true);
  final Uuid _uuid;

  Future<void>? _initialization;
  Future<void> _lastCommit = Future<void>.value();
  int _commitSequence = 0;
  bool _closed = false;

  NutritionStore(
    this._database,
    this._storage, {
    Uuid uuid = const Uuid(),
    NutritionPersistence? persistence,
  })  : _persistence = persistence ?? NutritionPersistence(_database, _storage),
        _uuid = uuid;

  /// Returns one coherent state after legacy reconciliation and database open.
  Future<ServiceResult<NutritionSnapshot>> snapshot() async {
    try {
      await _ensureInitialized();
      return Success(await _loadSnapshot());
    } catch (error, stackTrace) {
      debugPrint('NutritionStore snapshot failed: $error\n$stackTrace');
      return Failure(
        _errorType(error),
        'Could not load nutrition data: $error',
      );
    }
  }

  /// Emits only committed snapshots. The first event is the current snapshot.
  Stream<ServiceResult<NutritionSnapshot>> watch() async* {
    final initial = await snapshot();
    yield initial;
    yield* _changes.stream;
  }

  /// Applies a domain command as one serialized local commit.
  ///
  /// A successful result is returned only after the SQLite transaction has
  /// committed. Callers must publish in-memory state after this Future, never
  /// before it.
  Future<ServiceResult<CommitReceipt>> commit(
    NutritionCommand command,
  ) {
    if (_closed) {
      return Future<ServiceResult<CommitReceipt>>.value(
        const Failure(ServiceErrorType.unknown, 'NutritionStore is closed'),
      );
    }

    final completer = Completer<ServiceResult<CommitReceipt>>();
    final previous = _lastCommit;
    _lastCommit = _enqueueCommit(previous, command, completer);
    return completer.future;
  }

  /// Convenience for application controllers that use exceptions for failed
  /// persistence operations. The database commit still remains the only point
  /// at which in-memory state may be published.
  Future<CommitReceipt> commitOrThrow(NutritionCommand command) async {
    final result = await commit(command);
    return result.value;
  }

  Future<void> _enqueueCommit(
    Future<void> previous,
    NutritionCommand command,
    Completer<ServiceResult<CommitReceipt>> completer,
  ) async {
    try {
      await previous;
    } catch (_) {
      // A failed command is represented by its ServiceResult. It must not
      // prevent a later command from being attempted.
    }

    try {
      final result = await _commitNow(command);
      if (!completer.isCompleted) completer.complete(result);
    } catch (error, stackTrace) {
      debugPrint('NutritionStore commit failed: $error\n$stackTrace');
      if (!completer.isCompleted) {
        completer.complete(
          Failure(
            _errorType(error),
            'Could not persist nutrition data: $error',
          ),
        );
      }
    }
  }

  Future<ServiceResult<CommitReceipt>> _commitNow(
    NutritionCommand command,
  ) async {
    await _ensureInitialized();

    final transactionId = _uuid.v4();
    await _database.transaction(() async {
      await command.apply(this);
      final mutation = _syncMutationFor(command);
      if (mutation != null) {
        await _database.recordLocalMutation(
          entityType: mutation.entityType,
          entityId: mutation.entityId,
          operation: mutation.operation,
          payloadJson: mutation.payloadJson,
        );
      }
    });

    _commitSequence++;
    final receipt = CommitReceipt(
      transactionId: transactionId,
      commitSequence: _commitSequence,
      committedAtUtc: DateTime.now().toUtc(),
    );

    try {
      _changes.add(Success(await _loadSnapshot()));
    } catch (error, stackTrace) {
      // The entity commit already succeeded. Expose the read failure without
      // turning a durable write into a false failure for the caller.
      debugPrint(
        'NutritionStore snapshot after commit failed: $error\n$stackTrace',
      );
      _changes.add(
        Failure(_errorType(error), 'Could not publish committed state: $error'),
      );
    }

    return Success(receipt);
  }

  Future<void> _ensureInitialized() {
    return _initialization ??= _persistence.initialize();
  }

  Future<NutritionSnapshot> _loadSnapshot() async {
    final persistent = await _persistence.load();
    final foods = await _database.getAllFoods();
    final water = await _database.getAllWater();
    final weights = await _database.getAllWeights();
    final workouts = await _database.getAllWorkouts();
    final supplements = await _database.getAllSupplements();
    final supplementLogs = await _database.getAllSupplementLogs();
    final photos = await _database.getAllPhotos();

    return NutritionSnapshot(
      commitSequence: _commitSequence,
      goals: _storage.loadGoals(),
      profile: _storage.loadProfile(),
      foodEntries: List.unmodifiable(foods),
      waterEntries: List.unmodifiable(water),
      weightEntries: List.unmodifiable(weights),
      workoutEntries: List.unmodifiable(workouts),
      supplements: List.unmodifiable(supplements),
      supplementLogs: List.unmodifiable(supplementLogs),
      recipes: List.unmodifiable(persistent.recipes),
      plannedMeals: List.unmodifiable(persistent.plannedMeals),
      customFoods: List.unmodifiable(persistent.customFoods),
      favoriteFoods: List.unmodifiable(persistent.favoriteFoods),
      customPortions: List.unmodifiable(persistent.customPortions),
      recentFoods: List.unmodifiable(persistent.recentFoods),
      recentFoodMeals: Map.unmodifiable(persistent.recentFoodMeals),
      userStats: persistent.userStats,
      shoppingListChecked: Set.unmodifiable(persistent.shoppingListChecked),
      progressPhotos: List.unmodifiable(photos),
    );
  }

  Future<void> _saveRecipe(Recipe value) async {
    final state = await _persistence.load();
    final values = [...state.recipes];
    final index = values.indexWhere((item) => item.id == value.id);
    if (index == -1) {
      values.add(value);
    } else {
      values[index] = value;
    }
    await _persistence.saveRecipes(values, transactional: false);
  }

  Future<void> _deleteRecipe(String id) async {
    final state = await _persistence.load();
    await _persistence.saveRecipes(
      state.recipes.where((item) => item.id != id).toList(),
      transactional: false,
    );
  }

  Future<void> _saveCustomFood(FoodItem value) async {
    final state = await _persistence.load();
    final values = [...state.customFoods];
    final index = values.indexWhere((item) => item.id == value.id);
    if (index == -1) {
      values.insert(0, value);
    } else {
      values[index] = value;
    }
    await _persistence.saveCustomFoods(values, transactional: false);
  }

  Future<void> _deleteCustomFood(String id) async {
    final state = await _persistence.load();
    await _persistence.saveCustomFoods(
      state.customFoods.where((item) => item.id != id).toList(),
      transactional: false,
    );
  }

  Future<void> _saveFavoriteFood(FoodItem value) async {
    final state = await _persistence.load();
    final values = [...state.favoriteFoods];
    final index = values.indexWhere((item) => item.id == value.id);
    final favorite = value.copyWith(isFavorite: true);
    if (index == -1) {
      values.insert(0, favorite);
    } else {
      values[index] = favorite;
    }
    await _persistence.saveFavoriteFoods(values, transactional: false);
  }

  Future<void> _deleteFavoriteFood(String id) async {
    final state = await _persistence.load();
    await _persistence.saveFavoriteFoods(
      state.favoriteFoods.where((item) => item.id != id).toList(),
      transactional: false,
    );
  }

  Future<void> _savePlannedMeal(PlannedMeal value) async {
    final state = await _persistence.load();
    final values = [...state.plannedMeals];
    final index = values.indexWhere((item) => item.id == value.id);
    if (index == -1) {
      values.add(value);
    } else {
      values[index] = value;
    }
    await _persistence.savePlannedMeals(values, transactional: false);
  }

  Future<void> _savePlannedMeals(Iterable<PlannedMeal> values) async {
    final state = await _persistence.load();
    final meals = [...state.plannedMeals];
    for (final value in values) {
      final index = meals.indexWhere((item) => item.id == value.id);
      if (index == -1) {
        meals.add(value);
      } else {
        meals[index] = value;
      }
    }
    await _persistence.savePlannedMeals(meals, transactional: false);
  }

  Future<void> _deletePlannedMeal(String id) async {
    final state = await _persistence.load();
    await _persistence.savePlannedMeals(
      state.plannedMeals.where((item) => item.id != id).toList(),
      transactional: false,
    );
  }

  Future<void> _saveCustomPortion(CustomPortion value) async {
    final state = await _persistence.load();
    final values = [...state.customPortions];
    final index = values.indexWhere((item) => item.id == value.id);
    if (index == -1) {
      values.add(value);
    } else {
      values[index] = value;
    }
    await _persistence.saveCustomPortions(values, transactional: false);
  }

  Future<void> _deleteCustomPortion(String id) async {
    final state = await _persistence.load();
    await _persistence.saveCustomPortions(
      state.customPortions.where((item) => item.id != id).toList(),
      transactional: false,
    );
  }

  Future<void> _setShoppingItemChecked(
    String key, {
    required bool checked,
  }) async {
    final state = await _persistence.load();
    final values = {...state.shoppingListChecked};
    if (checked) {
      values.add(key);
    } else {
      values.remove(key);
    }
    await _persistence.saveShoppingListChecked(
      values,
      transactional: false,
    );
  }

  Future<void> _clearShoppingItems() => _persistence.saveShoppingListChecked(
        const <String>{},
        transactional: false,
      );

  Future<void> _saveSupplementOrder(List<String> orderedIds) async {
    final supplements = await _database.getAllSupplements();
    final byId = {for (final value in supplements) value.id: value};
    final ordered = <Supplement>[];
    for (var index = 0; index < orderedIds.length; index++) {
      final supplement = byId[orderedIds[index]];
      if (supplement == null) continue;
      ordered.add(supplement.copyWith(sortOrder: index));
    }
    await _database.batchUpdateSupplements(ordered);
  }

  Future<void> _saveRecentFood(FoodItem food, String? meal) async {
    final state = await _persistence.load();
    final recent = [...state.recentFoods]
      ..removeWhere((item) => item.id == food.id);
    recent.insert(0, food);
    final meals = {...state.recentFoodMeals};
    if (meal != null) meals[food.id] = meal;
    await _persistence.saveRecentFoods(recent, meals);
  }

  Future<void> _saveGoals(NutritionGoals? goals) async {
    if (goals == null) {
      await _storage.clearGoals();
      return;
    }
    await _storage.saveGoals(goals);
  }

  Future<void> _saveProfile(UserProfile? profile) async {
    if (profile == null) {
      await _storage.clearProfile();
      return;
    }
    await _storage.saveProfile(profile);
  }

  Future<void> _saveUserStats(UserStats value) =>
      _persistence.saveUserStats(value);

  Future<void> _saveProgressPhoto(ProgressPhoto value) =>
      _database.upsertPhoto(value);

  Future<void> _deleteProgressPhoto(String id) =>
      _database.deletePhoto(id).then((_) {});

  Future<void> _clearAll() async {
    await _database.deleteAllData(transactional: false);
    await _storage.clear();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _changes.close();
    await _database.close();
  }

  ServiceErrorType _errorType(Object error) {
    if (error is FormatException) return ServiceErrorType.parseError;
    if (error is ArgumentError) return ServiceErrorType.parseError;
    if (error is StateError) return ServiceErrorType.unknown;
    return ServiceErrorType.unknown;
  }
}

sealed class NutritionCommand {
  const NutritionCommand();

  Future<void> apply(NutritionStore store);
}

final class SaveFoodEntry extends NutritionCommand {
  final FoodEntry value;
  const SaveFoodEntry(this.value);

  @override
  Future<void> apply(NutritionStore store) async {
    final db = store._database;
    final existing = await db.getAllFoods();
    if (existing.any((entry) => entry.id == value.id)) {
      await db.updateFood(value);
    } else {
      await db.insertFood(value);
    }
  }
}

final class DeleteFoodEntry extends NutritionCommand {
  final String id;
  const DeleteFoodEntry(this.id);

  @override
  Future<void> apply(NutritionStore store) =>
      store._database.deleteFood(id).then((_) {});
}

final class SaveWaterEntry extends NutritionCommand {
  final WaterEntry value;
  const SaveWaterEntry(this.value);

  @override
  Future<void> apply(NutritionStore store) async {
    final db = store._database;
    final existing = await db.getAllWater();
    if (existing.any((entry) => entry.id == value.id)) {
      await db.deleteWater(value.id);
    }
    await db.insertWater(value);
  }
}

final class DeleteWaterEntry extends NutritionCommand {
  final String id;
  const DeleteWaterEntry(this.id);

  @override
  Future<void> apply(NutritionStore store) =>
      store._database.deleteWater(id).then((_) {});
}

final class SaveWeightEntry extends NutritionCommand {
  final WeightEntry value;
  const SaveWeightEntry(this.value);

  @override
  Future<void> apply(NutritionStore store) async {
    final db = store._database;
    final existing = await db.getAllWeights();
    if (existing.any((entry) => entry.id == value.id)) {
      await db.deleteWeight(value.id);
    }
    await db.insertWeight(value);
  }
}

final class DeleteWeightEntry extends NutritionCommand {
  final String id;
  const DeleteWeightEntry(this.id);

  @override
  Future<void> apply(NutritionStore store) =>
      store._database.deleteWeight(id).then((_) {});
}

final class SaveWorkoutEntry extends NutritionCommand {
  final WorkoutEntry value;
  const SaveWorkoutEntry(this.value);

  @override
  Future<void> apply(NutritionStore store) async {
    final db = store._database;
    final existing = await db.getAllWorkouts();
    if (existing.any((entry) => entry.id == value.id)) {
      await db.updateWorkout(value);
    } else {
      await db.insertWorkout(value);
    }
  }
}

final class DeleteWorkoutEntry extends NutritionCommand {
  final String id;
  const DeleteWorkoutEntry(this.id);

  @override
  Future<void> apply(NutritionStore store) =>
      store._database.deleteWorkout(id).then((_) {});
}

final class SaveRecipe extends NutritionCommand {
  final Recipe value;
  const SaveRecipe(this.value);

  @override
  Future<void> apply(NutritionStore store) => store._saveRecipe(value);
}

final class DeleteRecipe extends NutritionCommand {
  final String id;
  const DeleteRecipe(this.id);

  @override
  Future<void> apply(NutritionStore store) => store._deleteRecipe(id);
}

final class SaveCustomFood extends NutritionCommand {
  final FoodItem value;
  const SaveCustomFood(this.value);

  @override
  Future<void> apply(NutritionStore store) => store._saveCustomFood(value);
}

final class DeleteCustomFood extends NutritionCommand {
  final String id;
  const DeleteCustomFood(this.id);

  @override
  Future<void> apply(NutritionStore store) => store._deleteCustomFood(id);
}

final class SaveFavoriteFood extends NutritionCommand {
  final FoodItem value;
  const SaveFavoriteFood(this.value);

  @override
  Future<void> apply(NutritionStore store) => store._saveFavoriteFood(value);
}

final class DeleteFavoriteFood extends NutritionCommand {
  final String id;
  const DeleteFavoriteFood(this.id);

  @override
  Future<void> apply(NutritionStore store) => store._deleteFavoriteFood(id);
}

final class SavePlannedMeal extends NutritionCommand {
  final PlannedMeal value;
  const SavePlannedMeal(this.value);

  @override
  Future<void> apply(NutritionStore store) => store._savePlannedMeal(value);
}

final class SavePlannedMeals extends NutritionCommand {
  final List<PlannedMeal> values;
  SavePlannedMeals(Iterable<PlannedMeal> values)
      : values = List.unmodifiable(values);

  @override
  Future<void> apply(NutritionStore store) => store._savePlannedMeals(values);
}

final class DeletePlannedMeal extends NutritionCommand {
  final String id;
  const DeletePlannedMeal(this.id);

  @override
  Future<void> apply(NutritionStore store) => store._deletePlannedMeal(id);
}

final class SaveCustomPortion extends NutritionCommand {
  final CustomPortion value;
  const SaveCustomPortion(this.value);

  @override
  Future<void> apply(NutritionStore store) => store._saveCustomPortion(value);
}

final class DeleteCustomPortion extends NutritionCommand {
  final String id;
  const DeleteCustomPortion(this.id);

  @override
  Future<void> apply(NutritionStore store) => store._deleteCustomPortion(id);
}

final class SetShoppingItemChecked extends NutritionCommand {
  final String key;
  final bool checked;
  const SetShoppingItemChecked(this.key, {required this.checked});

  @override
  Future<void> apply(NutritionStore store) =>
      store._setShoppingItemChecked(key, checked: checked);
}

final class ClearShoppingItems extends NutritionCommand {
  const ClearShoppingItems();

  @override
  Future<void> apply(NutritionStore store) => store._clearShoppingItems();
}

final class SaveSupplement extends NutritionCommand {
  final Supplement value;
  const SaveSupplement(this.value);

  @override
  Future<void> apply(NutritionStore store) async {
    final db = store._database;
    final existing = await db.getAllSupplements();
    if (existing.any((entry) => entry.id == value.id)) {
      await db.updateSupplement(value);
    } else {
      await db.insertSupplement(value);
    }
  }
}

final class DeleteSupplement extends NutritionCommand {
  final String id;
  const DeleteSupplement(this.id);

  @override
  Future<void> apply(NutritionStore store) async {
    await store._database.deleteSupplement(id, transactional: false);
  }
}

final class SaveSupplementOrder extends NutritionCommand {
  final List<String> orderedIds;
  SaveSupplementOrder(Iterable<String> orderedIds)
      : orderedIds = List.unmodifiable(orderedIds);

  @override
  Future<void> apply(NutritionStore store) =>
      store._saveSupplementOrder(orderedIds);
}

final class SaveSupplementLog extends NutritionCommand {
  final SupplementLogEntry value;
  const SaveSupplementLog(this.value);

  @override
  Future<void> apply(NutritionStore store) =>
      store._database.insertSupplementLog(value).then((_) {});
}

final class DeleteSupplementLog extends NutritionCommand {
  final String id;
  const DeleteSupplementLog(this.id);

  @override
  Future<void> apply(NutritionStore store) =>
      store._database.deleteSupplementLog(id).then((_) {});
}

final class SaveProgressPhoto extends NutritionCommand {
  final ProgressPhoto value;
  const SaveProgressPhoto(this.value);

  @override
  Future<void> apply(NutritionStore store) => store._saveProgressPhoto(value);
}

final class DeleteProgressPhoto extends NutritionCommand {
  final String id;
  const DeleteProgressPhoto(this.id);

  @override
  Future<void> apply(NutritionStore store) => store._deleteProgressPhoto(id);
}

final class SaveUserStats extends NutritionCommand {
  final UserStats value;
  const SaveUserStats(this.value);

  @override
  Future<void> apply(NutritionStore store) => store._saveUserStats(value);
}

final class SaveGoals extends NutritionCommand {
  final NutritionGoals? value;
  const SaveGoals(this.value);

  @override
  Future<void> apply(NutritionStore store) => store._saveGoals(value);
}

final class SaveProfile extends NutritionCommand {
  final UserProfile? value;
  const SaveProfile(this.value);

  @override
  Future<void> apply(NutritionStore store) => store._saveProfile(value);
}

final class RememberRecentFood extends NutritionCommand {
  final FoodItem food;
  final String? meal;
  const RememberRecentFood(this.food, {this.meal});

  @override
  Future<void> apply(NutritionStore store) => store._saveRecentFood(food, meal);
}

final class ClearAllNutritionData extends NutritionCommand {
  const ClearAllNutritionData();

  @override
  Future<void> apply(NutritionStore store) => store._clearAll();
}

final class RestoreBackupV2 extends NutritionCommand {
  final NutritionBackup backup;
  const RestoreBackupV2(this.backup);

  @override
  Future<void> apply(NutritionStore store) async {
    await store._database.deleteNutritionData(transactional: false);
    await store._database.insertFoods(backup.foodEntries);
    await store._database.insertWaterList(backup.waterEntries);
    await store._database.insertWeightList(backup.weightEntries);
    await store._database.insertWorkoutList(backup.workoutEntries);
    await store._database.insertPhotos(backup.progressPhotos);
    await store._persistence.saveRecipes(
      backup.recipes,
      transactional: false,
    );
    await store._persistence.saveCustomFoods(
      backup.customFoods,
      transactional: false,
    );
    await store._persistence.saveFavoriteFoods(
      backup.favoriteFoods,
      transactional: false,
    );
    await store._persistence.savePlannedMeals(
      backup.plannedMeals,
      transactional: false,
    );
    await store._persistence.saveCustomPortions(
      backup.customPortions,
      transactional: false,
    );
    await store._persistence.saveRecentFoods(
      backup.recentFoods,
      backup.recentFoodMeals,
    );
    await store._persistence.saveUserStats(backup.userStats);
    await store._persistence.saveShoppingListChecked(
      backup.shoppingListChecked,
      transactional: false,
    );
    await store._saveGoals(backup.goals);
    await store._saveProfile(backup.profile);
  }
}

final class SyncMutation {
  final String entityType;
  final String entityId;
  final String operation;
  final String? payloadJson;

  const SyncMutation({
    required this.entityType,
    required this.entityId,
    required this.operation,
    this.payloadJson,
  });
}

SyncMutation? _syncMutationFor(NutritionCommand command) => switch (command) {
      SaveFoodEntry(:final value) => SyncMutation(
          entityType: 'food_entry',
          entityId: value.id,
          operation: 'upsert',
          payloadJson: jsonEncode(value.toJson()),
        ),
      DeleteFoodEntry(:final id) => SyncMutation(
          entityType: 'food_entry',
          entityId: id,
          operation: 'delete',
        ),
      SaveWaterEntry(:final value) => SyncMutation(
          entityType: 'water_entry',
          entityId: value.id,
          operation: 'upsert',
          payloadJson: jsonEncode(value.toJson()),
        ),
      DeleteWaterEntry(:final id) => SyncMutation(
          entityType: 'water_entry',
          entityId: id,
          operation: 'delete',
        ),
      SaveWeightEntry(:final value) => SyncMutation(
          entityType: 'weight_entry',
          entityId: value.id,
          operation: 'upsert',
          payloadJson: jsonEncode(value.toJson()),
        ),
      DeleteWeightEntry(:final id) => SyncMutation(
          entityType: 'weight_entry',
          entityId: id,
          operation: 'delete',
        ),
      SaveWorkoutEntry(:final value) => SyncMutation(
          entityType: 'workout_entry',
          entityId: value.id,
          operation: 'upsert',
          payloadJson: jsonEncode(value.toJson()),
        ),
      DeleteWorkoutEntry(:final id) => SyncMutation(
          entityType: 'workout_entry',
          entityId: id,
          operation: 'delete',
        ),
      SaveRecipe(:final value) => SyncMutation(
          entityType: 'recipe',
          entityId: value.id,
          operation: 'upsert',
          payloadJson: jsonEncode(value.toJson()),
        ),
      DeleteRecipe(:final id) => SyncMutation(
          entityType: 'recipe',
          entityId: id,
          operation: 'delete',
        ),
      SaveCustomFood(:final value) => SyncMutation(
          entityType: 'custom_food',
          entityId: value.id,
          operation: 'upsert',
          payloadJson: jsonEncode(value.toJson()),
        ),
      DeleteCustomFood(:final id) => SyncMutation(
          entityType: 'custom_food',
          entityId: id,
          operation: 'delete',
        ),
      SaveFavoriteFood(:final value) => SyncMutation(
          entityType: 'favorite_food',
          entityId: value.id,
          operation: 'upsert',
          payloadJson: jsonEncode(value.copyWith(isFavorite: true).toJson()),
        ),
      DeleteFavoriteFood(:final id) => SyncMutation(
          entityType: 'favorite_food',
          entityId: id,
          operation: 'delete',
        ),
      SavePlannedMeal(:final value) => SyncMutation(
          entityType: 'planned_meal',
          entityId: value.id,
          operation: 'upsert',
          payloadJson: jsonEncode(value.toJson()),
        ),
      SavePlannedMeals(:final values) => SyncMutation(
          entityType: 'planned_meals',
          entityId: 'collection',
          operation: 'upsert',
          payloadJson:
              jsonEncode(values.map((value) => value.toJson()).toList()),
        ),
      DeletePlannedMeal(:final id) => SyncMutation(
          entityType: 'planned_meal',
          entityId: id,
          operation: 'delete',
        ),
      SaveCustomPortion(:final value) => SyncMutation(
          entityType: 'custom_portion',
          entityId: value.id,
          operation: 'upsert',
          payloadJson: jsonEncode(value.toJson()),
        ),
      DeleteCustomPortion(:final id) => SyncMutation(
          entityType: 'custom_portion',
          entityId: id,
          operation: 'delete',
        ),
      SetShoppingItemChecked(:final key, :final checked) => SyncMutation(
          entityType: 'shopping_item',
          entityId: key,
          operation: checked ? 'upsert' : 'delete',
          payloadJson:
              checked ? jsonEncode({'key': key, 'checked': true}) : null,
        ),
      ClearShoppingItems() => const SyncMutation(
          entityType: 'shopping_items',
          entityId: 'collection',
          operation: 'delete',
        ),
      SaveSupplement(:final value) => SyncMutation(
          entityType: 'supplement',
          entityId: value.id,
          operation: 'upsert',
          payloadJson: jsonEncode(value.toJson()),
        ),
      DeleteSupplement(:final id) => SyncMutation(
          entityType: 'supplement',
          entityId: id,
          operation: 'delete',
        ),
      SaveSupplementOrder(:final orderedIds) => SyncMutation(
          entityType: 'supplement_order',
          entityId: 'collection',
          operation: 'upsert',
          payloadJson: jsonEncode(orderedIds),
        ),
      SaveSupplementLog(:final value) => SyncMutation(
          entityType: 'supplement_log',
          entityId: value.id,
          operation: 'upsert',
          payloadJson: jsonEncode(value.toJson()),
        ),
      DeleteSupplementLog(:final id) => SyncMutation(
          entityType: 'supplement_log',
          entityId: id,
          operation: 'delete',
        ),
      SaveProgressPhoto(:final value) => SyncMutation(
          entityType: 'progress_photo',
          entityId: value.id,
          operation: 'upsert',
          payloadJson: jsonEncode(value.toJson()),
        ),
      DeleteProgressPhoto(:final id) => SyncMutation(
          entityType: 'progress_photo',
          entityId: id,
          operation: 'delete',
        ),
      SaveUserStats(:final value) => SyncMutation(
          entityType: 'user_stats',
          entityId: 'default',
          operation: 'upsert',
          payloadJson: jsonEncode(value.toJson()),
        ),
      SaveGoals(:final value) => SyncMutation(
          entityType: 'goals',
          entityId: 'default',
          operation: value == null ? 'delete' : 'upsert',
          payloadJson: value == null ? null : jsonEncode(value.toJson()),
        ),
      SaveProfile(:final value) => SyncMutation(
          entityType: 'profile',
          entityId: 'default',
          operation: value == null ? 'delete' : 'upsert',
          payloadJson: value == null ? null : jsonEncode(value.toJson()),
        ),
      RestoreBackupV2() => const SyncMutation(
          entityType: 'nutrition_snapshot',
          entityId: 'default',
          operation: 'restore',
        ),
      _ => null,
    };

final class NutritionSnapshot {
  final int commitSequence;
  final NutritionGoals? goals;
  final UserProfile? profile;
  final List<FoodEntry> foodEntries;
  final List<WaterEntry> waterEntries;
  final List<WeightEntry> weightEntries;
  final List<WorkoutEntry> workoutEntries;
  final List<Supplement> supplements;
  final List<SupplementLogEntry> supplementLogs;
  final List<Recipe> recipes;
  final List<PlannedMeal> plannedMeals;
  final List<FoodItem> customFoods;
  final List<FoodItem> favoriteFoods;
  final List<CustomPortion> customPortions;
  final List<FoodItem> recentFoods;
  final Map<String, String> recentFoodMeals;
  final UserStats userStats;
  final Set<String> shoppingListChecked;
  final List<ProgressPhoto> progressPhotos;

  const NutritionSnapshot({
    required this.commitSequence,
    required this.goals,
    required this.profile,
    required this.foodEntries,
    required this.waterEntries,
    required this.weightEntries,
    required this.workoutEntries,
    required this.supplements,
    required this.supplementLogs,
    required this.recipes,
    required this.plannedMeals,
    required this.customFoods,
    required this.favoriteFoods,
    required this.customPortions,
    required this.recentFoods,
    required this.recentFoodMeals,
    required this.userStats,
    required this.shoppingListChecked,
    required this.progressPhotos,
  });
}

final class CommitReceipt {
  final String transactionId;
  final int commitSequence;
  final DateTime committedAtUtc;

  const CommitReceipt({
    required this.transactionId,
    required this.commitSequence,
    required this.committedAtUtc,
  });
}
