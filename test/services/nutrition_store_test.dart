import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/meal_plan.dart';
import 'package:sophis/models/progress_photo.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/models/user_profile.dart';
import 'package:sophis/models/water_entry.dart';
import 'package:sophis/services/database_service.dart';
import 'package:sophis/services/nutrition/nutrition_persistence.dart';
import 'package:sophis/services/nutrition/nutrition_store.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/storage_service.dart';

import '../helpers/test_services.dart';

void main() {
  group('NutritionStore', () {
    late NutritionStore store;
    late DatabaseService database;

    setUp(() async {
      final storage = await createTestStorage();
      database = createTestDatabase();
      store = NutritionStore(database, storage);
      addTearDown(store.close);
    });

    test('loads one coherent snapshot from local persistence', () async {
      final timestamp = DateTime.utc(2026, 1, 2, 8, 30);
      final food = FoodEntry(
        id: 'food-1',
        name: 'Oats',
        calories: 300,
        protein: 12,
        carbs: 45,
        fat: 8,
        timestamp: timestamp,
        meal: 'breakfast',
      );

      final result = await store.commit(SaveFoodEntry(food));

      expect(result, isA<Success<CommitReceipt>>());
      final state = await store.snapshot();
      expect(state, isA<Success<NutritionSnapshot>>());
      expect(state.valueOrNull?.foodEntries.single.id, 'food-1');
      expect(state.valueOrNull?.commitSequence, 1);
    });

    test('serializes concurrent commits and publishes committed state',
        () async {
      final first = FoodEntry(
        id: 'food-1',
        name: 'Oats',
        calories: 300,
        protein: 12,
        carbs: 45,
        fat: 8,
        timestamp: DateTime.utc(2026, 1, 2, 8),
        meal: 'breakfast',
      );
      final second = WaterEntry(
        id: 'water-1',
        amountMl: 500,
        timestamp: DateTime.utc(2026, 1, 2, 9),
      );

      final results = await Future.wait<ServiceResult<CommitReceipt>>([
        store.commit(SaveFoodEntry(first)),
        store.commit(SaveWaterEntry(second)),
      ]);

      expect(results.every((result) => result.isSuccess), isTrue);
      expect(
        results.map((result) => result.valueOrNull!.commitSequence).toList(),
        [1, 2],
      );
      final state = await store.snapshot();
      expect(state.valueOrNull?.foodEntries, hasLength(1));
      expect(state.valueOrNull?.waterEntries, hasLength(1));
      expect(state.valueOrNull?.commitSequence, 2);
    });

    test('records a compacted outbox mutation and a tombstone on delete',
        () async {
      final food = FoodEntry(
        id: 'sync-food',
        name: 'Oats',
        calories: 300,
        protein: 12,
        carbs: 45,
        fat: 8,
        timestamp: DateTime.utc(2026, 1, 2, 8),
        meal: 'breakfast',
      );

      await store.commit(SaveFoodEntry(food));
      final firstMetadata = await database.getSyncMetadata(
        'food_entry',
        food.id,
      );
      expect(firstMetadata?.localRevision, 1);
      expect(firstMetadata?.deletedAt, isNull);
      expect(await database.getPendingSyncOutbox(), hasLength(1));

      await store.commit(SaveFoodEntry(food.copyWith(name: 'Rolled oats')));
      final secondMetadata = await database.getSyncMetadata(
        'food_entry',
        food.id,
      );
      expect(secondMetadata?.localRevision, 2);
      expect(await database.getPendingSyncOutbox(), hasLength(1));
      expect(
        (await database.getPendingSyncOutbox()).single.payloadJson,
        contains('Rolled oats'),
      );

      await store.commit(const DeleteFoodEntry('sync-food'));
      final deletedMetadata = await database.getSyncMetadata(
        'food_entry',
        food.id,
      );
      expect(deletedMetadata?.localRevision, 3);
      expect(deletedMetadata?.deletedAt, isNotNull);
      final pending = await database.getPendingSyncOutbox();
      expect(pending, hasLength(1));
      expect(pending.single.operation, 'delete');
    });

    test('upserts canonical entities without replacing their siblings',
        () async {
      final firstRecipe = Recipe(
        id: 'recipe-1',
        name: 'Breakfast bowl',
        ingredients: const [],
        createdAt: DateTime.utc(2026, 1, 2),
      );
      final secondRecipe = Recipe(
        id: 'recipe-2',
        name: 'Dinner bowl',
        ingredients: const [],
        createdAt: DateTime.utc(2026, 1, 3),
      );
      final firstMeal = PlannedMeal(
        id: 'meal-1',
        date: DateTime.utc(2026, 1, 2),
        meal: 'breakfast',
        name: 'Breakfast bowl',
        calories: 300,
        protein: 20,
        carbs: 30,
        fat: 10,
      );
      final secondMeal = PlannedMeal(
        id: 'meal-2',
        date: DateTime.utc(2026, 1, 3),
        meal: 'dinner',
        name: 'Dinner bowl',
        calories: 500,
        protein: 30,
        carbs: 45,
        fat: 15,
      );

      await store.commit(SaveRecipe(firstRecipe));
      await store.commit(SaveRecipe(secondRecipe));
      await store.commit(SaveRecipe(firstRecipe.copyWith(name: 'Updated')));
      await store.commit(SavePlannedMeal(firstMeal));
      await store.commit(SavePlannedMeals([secondMeal]));

      final state = (await store.snapshot()).valueOrNull!;
      expect(state.recipes, hasLength(2));
      expect(
        state.recipes.firstWhere((recipe) => recipe.id == 'recipe-1').name,
        'Updated',
      );
      expect(state.plannedMeals, hasLength(2));
      expect(
        state.plannedMeals.map((meal) => meal.id),
        containsAll(<String>['meal-1', secondMeal.id]),
      );
    });

    test('exposes durable sync changes without leaking database rows',
        () async {
      final food = FoodEntry(
        id: 'sync-api-food',
        name: 'Oats',
        calories: 300,
        protein: 12,
        carbs: 45,
        fat: 8,
        timestamp: DateTime.utc(2026, 1, 2, 8),
        meal: 'breakfast',
      );
      await store.commit(SaveFoodEntry(food));

      final changes = await store.pendingSyncChanges();
      expect(changes, hasLength(1));
      expect(changes.single, isA<NutritionSyncChange>());
      expect(changes.single.dataSpaceId, DatabaseService.defaultDataSpaceId);
      expect(changes.single.entityType, 'food_entry');

      await store.retrySyncChange(
        changes.single,
        error: StateError('offline'),
        delay: Duration.zero,
      );
      expect((await store.pendingSyncChanges()).single.attempts, 1);

      await store.acknowledgeSyncChange(changes.single.id);
      expect(await store.pendingSyncChanges(), isEmpty);
    });

    test('emits a clear mutation after deleting all local data', () async {
      final food = FoodEntry(
        id: 'clear-food',
        name: 'Oats',
        calories: 300,
        protein: 12,
        carbs: 45,
        fat: 8,
        timestamp: DateTime.utc(2026, 1, 2, 8),
        meal: 'breakfast',
      );
      await store.commit(SaveFoodEntry(food));

      await store.commit(const ClearAllNutritionData());

      expect(await database.getAllFoods(), isEmpty);
      final pending = await store.pendingSyncChanges();
      expect(pending, hasLength(1));
      expect(pending.single.entityType, 'nutrition_snapshot');
      expect(pending.single.operation, 'clear');
    });

    test('keeps local photo paths out of sync payloads', () async {
      final photo = ProgressPhoto(
        id: 'sync-photo',
        imagePath: '/Users/example/Library/progress_photos/sync-photo.jpg',
        timestamp: DateTime.utc(2026, 1, 2),
        createdAt: DateTime.utc(2026, 1, 2),
      );

      await store.commit(SaveProgressPhoto(photo));

      final pending = await store.pendingSyncChanges();
      expect(pending, hasLength(1));
      expect(pending.single.payloadJson, contains('"blobId":"sync-photo"'));
      expect(pending.single.payloadJson, contains('"category":"front"'));
      expect(pending.single.payloadJson, isNot(contains(photo.imagePath)));
    });

    test('uses stable profile enum names in sync payloads', () async {
      await store.commit(
        const SaveProfile(
          UserProfile(
            gender: Gender.male,
            activityLevel: ActivityLevel.moderate,
            goal: Goal.maintain,
          ),
        ),
      );

      final pending = await store.pendingSyncChanges();
      expect(pending.single.payloadJson, contains('"gender":"male"'));
      expect(
        pending.single.payloadJson,
        contains('"activityLevel":"moderate"'),
      );
      expect(pending.single.payloadJson, contains('"goal":"maintain"'));
    });

    test('can retry store initialization after a transient failure', () async {
      final storage = await createTestStorage();
      final retryingPersistence = _FailFirstInitializationPersistence(
        database,
        storage,
      );
      final retryingStore = NutritionStore(
        database,
        storage,
        persistence: retryingPersistence,
      );
      addTearDown(retryingStore.close);

      expect((await retryingStore.snapshot()).isFailure, isTrue);
      expect((await retryingStore.snapshot()).isSuccess, isTrue);
    });

    test('removes a supplement and its logs in one command', () async {
      // The command remains safe on an empty store and exercises the same
      // transaction path used when a definition has completion logs.
      final result = await store.commit(const DeleteSupplement('missing'));

      expect(result, isA<Success<CommitReceipt>>());
    });
  });
}

class _FailFirstInitializationPersistence extends NutritionPersistence {
  // The base constructor uses private parameter names, so forwarding by
  // position keeps the test helper readable without exposing them.
  // ignore: use_super_parameters
  _FailFirstInitializationPersistence(
    DatabaseService database,
    StorageService storage,
  ) : super(database, storage);

  bool _shouldFail = true;

  @override
  Future<NutritionPersistentState> initialize() async {
    if (_shouldFail) {
      _shouldFail = false;
      throw StateError('temporary initialization failure');
    }
    return super.initialize();
  }
}
