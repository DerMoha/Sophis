import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/models/shareable_meal.dart';
import 'package:sophis/models/social/social_snapshot.dart';
import 'package:sophis/services/database_service.dart';
import 'package:sophis/services/nutrition/nutrition_store.dart';

import '../../helpers/test_services.dart';

void main() {
  final date = DateTime(2026, 10, 7, 12);
  final snapshot = SocialSnapshot(
    title: 'Dinner for two',
    servings: 2,
    items: const [
      SharedFoodItem(
        name: 'Rice',
        calories: 400,
        protein: 8,
        carbs: 88,
        fat: 1,
        portionGrams: 300,
        portionUnit: NutritionUnit.gram,
      ),
      SharedFoodItem(
        name: 'Sauce',
        calories: 100,
        protein: 1,
        carbs: 5,
        fat: 8,
      ),
    ],
  );
  late DatabaseService database;
  late NutritionStore store;
  setUp(() async {
    database = createTestDatabase();
    store = NutritionStore(database, await createTestStorage());
  });
  tearDown(() async => store.close());
  ImportSocialMeal imported(String operation) => ImportSocialMeal(
        operationId: operation,
        snapshot: snapshot,
        selectedServings: 0.5,
        timestamp: date,
        meal: 'lunch',
      );

  group('SocialImport', () {
    test('committed all selected portions once under concurrent retries',
        () async {
      final results = await Future.wait(
        [store.commit(imported('one')), store.commit(imported('one'))],
      );
      expect(results.every((result) => result.isSuccess), isTrue);
      final foods = (await store.snapshot()).value.foodEntries;
      expect(foods, hasLength(2));
      expect(foods.fold(0.0, (sum, food) => sum + food.calories), 125);
      expect(
        foods.singleWhere((food) => food.name == 'Rice').portionAmount,
        75,
      );
      expect(await store.pendingSyncChanges(), hasLength(2));
      expect(
        await database.readNutritionDocument('social_import:diary:one'),
        isNotNull,
      );
    });
    test('preserved recipient edits and deletion when an old import retried',
        () async {
      await store.commit(imported('one'));
      final foods = (await store.snapshot()).value.foodEntries;
      final edited =
          foods.first.copyWith(name: 'My edited portion', calories: 999);
      await store.commit(SaveFoodEntry(edited));
      await store.commit(DeleteFoodEntry(foods.last.id));
      await store.commit(imported('one'));
      final after = (await store.snapshot()).value.foodEntries;
      expect(after, hasLength(1));
      expect(after.single.name, 'My edited portion');
      expect(after.single.calories, 999);
    });
    test('allowed intentional repeats with new operation IDs', () async {
      await store.commit(imported('one'));
      await store.commit(imported('two'));
      expect((await store.snapshot()).value.foodEntries, hasLength(4));
    });
    test(
        'rolled back the whole import and receipt if an ingredient write failed',
        () async {
      await store.snapshot();
      await database.customStatement('''
        CREATE TRIGGER fail_social_import BEFORE INSERT ON foods
        WHEN NEW.name = 'Sauce' BEGIN SELECT RAISE(ABORT, 'simulated write failure'); END
      ''');
      expect((await store.commit(imported('one'))).isFailure, isTrue);
      expect((await store.snapshot()).value.foodEntries, isEmpty);
      expect(
        await database.readNutritionDocument('social_import:diary:one'),
        isNull,
      );
      expect(await store.pendingSyncChanges(), isEmpty);
      await database.customStatement('DROP TRIGGER fail_social_import');
      expect((await store.commit(imported('one'))).isSuccess, isTrue);
      expect((await store.snapshot()).value.foodEntries, hasLength(2));
    });
    test(
        'saved independent recipe and ingredient IDs and kept recipient edits on retry',
        () async {
      final source = Recipe(
        id: 'authorRecipe',
        name: 'Rice for two',
        servings: 2,
        createdAt: date,
        ingredients: const [
          RecipeIngredient(
            id: 'authorIngredient',
            name: 'Rice',
            amountGrams: 300,
            calories: 400,
            protein: 8,
            carbs: 88,
            fat: 1,
          ),
        ],
      );
      final command = ImportSocialRecipe(operationId: 'copy1', recipe: source);
      await store.commit(command);
      final copy = (await store.snapshot()).value.recipes.single;
      expect(copy.id, isNot(source.id));
      expect(copy.ingredients.single.id, isNot(source.ingredients.single.id));
      expect(copy.nutrientsPerServing.calories, 200);
      await store.commit(SaveRecipe(copy.copyWith(name: 'My recipe')));
      await store.commit(command);
      expect((await store.snapshot()).value.recipes.single.name, 'My recipe');
      await store.commit(DeleteRecipe(copy.id));
      await store.commit(command);
      expect((await store.snapshot()).value.recipes, isEmpty);
    });
    test('rejected hidden nutrition and invalid selections before committing',
        () {
      final hidden = SocialSnapshot.fromJson(
        snapshot.toJson(nutritionVisible: false),
        nutritionVisible: false,
      );
      expect(
        () => ImportSocialMeal(
          operationId: 'one',
          snapshot: hidden,
          selectedServings: 1,
          timestamp: date,
          meal: 'lunch',
        ),
        throwsStateError,
      );
      expect(
        () => ImportSocialMeal(
          operationId: 'one',
          snapshot: snapshot,
          selectedServings: 0,
          timestamp: date,
          meal: 'lunch',
        ),
        throwsFormatException,
      );
    });
  });
}
