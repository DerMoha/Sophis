import 'package:drift/drift.dart' show Migrator;
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/services/database_service.dart';
import 'package:sophis/services/nutrition/nutrition_store.dart';

import '../../helpers/test_services.dart';

void main() {
  late DatabaseService database;
  late NutritionStore store;
  late DateTime now;
  FoodEntry entry(String id) => FoodEntry(
        id: id,
        name: 'Rice',
        calories: 100,
        protein: 2,
        carbs: 20,
        fat: 1,
        timestamp: DateTime.utc(2020),
        meal: 'lunch',
      );
  setUp(() async {
    now = DateTime.utc(2026, 10, 7, 12);
    database = createTestDatabase();
    store =
        NutritionStore(database, await createTestStorage(), clock: () => now);
  });
  tearDown(() async => store.close());

  group('FoodSharingOrigin', () {
    test('kept actual logging time through backdating and edits', () async {
      await store.commit(SaveFoodEntry(entry('one')));
      final first = (await store.foodSharingChanges()).single;
      expect(first.originallyLoggedAt, now);
      expect(first.entry!.timestamp.year, 2020);
      now = now.add(const Duration(hours: 1));
      await store.commit(SaveFoodEntry(entry('one').copyWith(calories: 200)));
      final edited = (await store.foodSharingChanges()).single;
      expect(edited.originallyLoggedAt, first.originallyLoggedAt);
      expect(edited.changedAt, now);
      expect(edited.revision, 2);
      expect(edited.sequence, greaterThan(first.sequence));
    });
    test('did not classify legacy or restored diary rows as new logging',
        () async {
      await store.snapshot();
      await database.upsertFood(entry('legacy'));
      await store
          .commit(SaveFoodEntry(entry('legacy').copyWith(calories: 200)));
      expect(
        (await store.foodSharingChanges()).single.originallyLoggedAt,
        isNull,
      );
      await store.commit(SaveFoodEntry(entry('new')));
      await store.commit(const DeleteFoodEntry('new'));
      await database.upsertFood(entry('new'));
      await store.commit(SaveFoodEntry(entry('new')));
      expect(
        (await store.foodSharingChanges()).last.originallyLoggedAt,
        isNull,
      );
    });
    test('retained deletion facts without deleted food content', () async {
      await store.commit(SaveFoodEntry(entry('one')));
      final first = (await store.foodSharingChanges()).single;
      await store.commit(const DeleteFoodEntry('one'));
      final deletion =
          (await store.foodSharingChanges(afterSequence: first.sequence))
              .single;
      expect(deletion.deleted, isTrue);
      expect(deletion.entry, isNull);
      expect(deletion.originallyLoggedAt, first.originallyLoggedAt);
      expect(deletion.revision, 2);
    });
    test('serialized sequences and supported incremental reads', () async {
      await Future.wait([
        store.commit(SaveFoodEntry(entry('one'))),
        store.commit(SaveFoodEntry(entry('two'))),
      ]);
      final changes = await store.foodSharingChanges(limit: 1);
      expect(changes, hasLength(1));
      final next = await store.foodSharingChanges(
        afterSequence: changes.single.sequence,
      );
      expect(next, hasLength(1));
      expect(next.single.foodId, isNot(changes.single.foodId));
    });
    test('rolled back sharing metadata with failed diary writes', () async {
      await store.snapshot();
      await database.customStatement(
        "CREATE TRIGGER fail_food BEFORE INSERT ON foods BEGIN SELECT RAISE(ABORT, 'failure'); END",
      );
      expect(
        (await store.commit(SaveFoodEntry(entry('one')))).isFailure,
        isTrue,
      );
      expect(await store.foodSharingChanges(), isEmpty);
      await database.customStatement('DROP TRIGGER fail_food');
      await store.commit(SaveFoodEntry(entry('one')));
      expect((await store.foodSharingChanges()).single.revision, 1);
    });
    test('migrated the ledger additively without classifying existing foods',
        () async {
      await store.snapshot();
      await database.upsertFood(entry('legacy'));
      await database.customStatement('DROP TABLE food_sharing_origins');
      await database.migration.onUpgrade(Migrator(database), 12, 13);
      expect(await database.getAllFoods(), hasLength(1));
      expect(await store.foodSharingChanges(), isEmpty);
      final indexes = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'food_sharing_origins_sequence_idx'",
          )
          .get();
      expect(indexes, hasLength(1));
    });
  });
}
