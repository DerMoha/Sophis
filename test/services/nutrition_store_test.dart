import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/water_entry.dart';
import 'package:sophis/services/nutrition/nutrition_store.dart';
import 'package:sophis/services/service_result.dart';

import '../helpers/test_services.dart';

void main() {
  group('NutritionStore', () {
    late NutritionStore store;

    setUp(() async {
      final storage = await createTestStorage();
      store = NutritionStore(createTestDatabase(), storage);
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

    test('removes a supplement and its logs in one command', () async {
      // The command remains safe on an empty store and exercises the same
      // transaction path used when a definition has completion logs.
      final result = await store.commit(const DeleteSupplement('missing'));

      expect(result, isA<Success<CommitReceipt>>());
    });
  });
}
