import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/models/social/social_snapshot.dart';

void main() {
  final timestamp = DateTime(2026, 10, 7, 12);
  final source = FoodEntry(
    id: 'private-id',
    name: 'Rice',
    calories: 400,
    protein: 8,
    carbs: 88,
    fat: 1,
    timestamp: timestamp,
    meal: 'dinner',
    sourceFoodId: 'private-source',
    portionAmount: 300,
    portionUnit: NutritionUnit.gram,
    portionLabel: 'bowl',
    portionQuantity: 2,
  );

  group('SocialSnapshot', () {
    test('excluded source IDs and diary timestamps from publication', () {
      final snapshot = SocialSnapshot.fromEntries([source], title: 'Dinner');
      final json = snapshot.toJson(nutritionVisible: true);
      final item = (json['items'] as List).single as Map;
      expect(item.containsKey('id'), isFalse);
      expect(item.containsKey('sourceFoodId'), isFalse);
      expect(item.containsKey('timestamp'), isFalse);
      expect(item['portionUnit'], 'g');
      expect(
        SocialSnapshot.fromJson(json, nutritionVisible: true)
            .items
            .single
            .calories,
        400,
      );
    });

    test('omitted hidden nutrition and prevented zero-calorie diary imports',
        () {
      final snapshot = SocialSnapshot.fromEntries([source], title: 'Dinner');
      final json = snapshot.toJson(nutritionVisible: false);
      expect((json['items'] as List).single, isNot(contains('calories')));
      final hidden = SocialSnapshot.fromJson(json, nutritionVisible: false);
      expect(
        (hidden.toJson(nutritionVisible: true)['items'] as List).single,
        isNot(contains('calories')),
      );
      expect(
        () => hidden.entriesForImport(
          operationId: 'import1',
          selectedServings: 1,
          timestamp: timestamp,
          meal: 'lunch',
          nutritionVisible: false,
        ),
        throwsStateError,
      );
    });

    test('scaled source amounts and nutrients by selected recipe servings', () {
      final recipe = Recipe(
        id: 'private-recipe',
        name: 'Rice for two',
        servings: 2,
        createdAt: timestamp,
        ingredients: const [
          RecipeIngredient(
            id: 'private-ingredient',
            name: 'Rice',
            amountGrams: 300,
            calories: 400,
            protein: 8,
            carbs: 88,
            fat: 1,
          ),
        ],
      );
      final snapshot = SocialSnapshot.fromRecipe(recipe);
      final entries = snapshot.entriesForImport(
        operationId: 'import1',
        selectedServings: 0.5,
        timestamp: timestamp,
        meal: 'lunch',
        nutritionVisible: true,
      );
      expect(entries.single.calories, 100);
      expect(entries.single.portionAmount, 75);
      expect(entries.single.sourceFoodId, isNull);
      expect(entries.single.id, isNot(recipe.ingredients.single.id));
      expect(entries.single.meal, 'lunch');
    });

    test('kept retry IDs stable and intentional repeats independent', () {
      final snapshot = SocialSnapshot.fromEntries([source], title: 'Dinner');
      List<FoodEntry> imported(String operation) => snapshot.entriesForImport(
            operationId: operation,
            selectedServings: 1,
            timestamp: timestamp,
            meal: 'dinner',
            nutritionVisible: true,
          );
      expect(imported('one').single.id, imported('one').single.id);
      expect(imported('one').single.id, isNot(imported('two').single.id));
      final changed = source.copyWith(calories: 999);
      expect(changed.calories, 999);
      expect(imported('one').single.calories, 400);
    });

    test('rejected invalid portions, unknown versions and non-finite nutrition',
        () {
      expect(
        () => SocialSnapshot.fromEntries(
          [source.copyWith(calories: double.nan)],
          title: 'Dinner',
        ),
        throwsFormatException,
      );
      expect(
        () => SocialSnapshot.fromEntries(
          [source.copyWith(portionAmount: -1)],
          title: 'Dinner',
        ),
        throwsFormatException,
      );
      expect(
        () => SocialSnapshot.fromEntries(
          [source.copyWith(portionLabel: 'x' * 161)],
          title: 'Dinner',
        ),
        throwsFormatException,
      );
      expect(
        () => SocialSnapshot.fromJson(
          {'schemaVersion': 99},
          nutritionVisible: true,
        ),
        throwsFormatException,
      );
    });
  });
}
