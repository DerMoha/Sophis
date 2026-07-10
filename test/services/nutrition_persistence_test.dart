import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/services/nutrition/nutrition_persistence.dart';

import '../helpers/test_services.dart';

void main() {
  group('NutritionPersistence v3 reconciliation', () {
    test('preserves legacy SQLite data when preference key is absent',
        () async {
      final storage = await createTestStorage(
        initialValues: const {'db_migration_v2_complete': true},
      );
      final database = createTestDatabase();
      addTearDown(database.close);
      final recipe = Recipe(
        id: 'sqlite-recipe',
        name: 'SQLite recipe',
        ingredients: const [],
        createdAt: DateTime(2026, 1, 2),
      );
      await database.migrateRecipe(recipe);

      final persistence = NutritionPersistence(database, storage);
      final state = await persistence.initialize();

      expect(state.recipes.single.id, 'sqlite-recipe');
      expect(storage.isMigrationV3Complete(), isTrue);
    });

    test('treats a present empty preference as an intentional deletion',
        () async {
      final storage = await createTestStorage(
        initialValues: const {
          'db_migration_v2_complete': true,
          'recipes': '[]',
        },
      );
      final database = createTestDatabase();
      addTearDown(database.close);
      await database.migrateRecipe(
        Recipe(
          id: 'stale-recipe',
          name: 'Stale recipe',
          ingredients: const [],
          createdAt: DateTime(2026, 1, 2),
        ),
      );

      final state = await NutritionPersistence(database, storage).initialize();

      expect(state.recipes, isEmpty);
      expect(storage.loadRecipes(), isEmpty);
    });

    test('persists complete favorite records and recent meal metadata',
        () async {
      final storage = await createTestStorage();
      final database = createTestDatabase();
      addTearDown(database.close);
      final persistence = NutritionPersistence(database, storage);
      await persistence.initialize();
      const food = FoodItem(
        id: 'food-1',
        name: 'Yogurt',
        category: 'dairy',
        caloriesPer100g: 80,
        proteinPer100g: 9,
        carbsPer100g: 4,
        fatPer100g: 2,
      );

      await persistence.saveFavoriteFoods([
        food.copyWith(isFavorite: true),
      ]);
      await persistence.saveRecentFoods([food], {'food-1': 'breakfast'});

      final reloaded = await NutritionPersistence(database, storage).load();
      expect(reloaded.favoriteFoods.single.name, 'Yogurt');
      expect(reloaded.favoriteFoods.single.isFavorite, isTrue);
      expect(reloaded.recentFoodMeals['food-1'], 'breakfast');
    });
  });
}
