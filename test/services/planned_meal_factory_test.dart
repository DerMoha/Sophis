import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/meal_plan.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/services/gemini/models/models.dart';
import 'package:sophis/services/planned_meal_factory.dart';

void main() {
  group('PlannedMealFactory', () {
    test('builds a planned meal from a recipe with scaled servings', () {
      final recipe = Recipe(
        id: 'recipe-1',
        name: 'Chicken Rice Bowl',
        servings: 2,
        createdAt: DateTime(2026, 1, 1),
        ingredients: const [
          RecipeIngredient(
            id: '1',
            name: 'Chicken Breast',
            amountGrams: 200,
            calories: 330,
            protein: 62,
            carbs: 0,
            fat: 7,
          ),
          RecipeIngredient(
            id: '2',
            name: 'Rice',
            amountGrams: 180,
            calories: 234,
            protein: 4.5,
            carbs: 50,
            fat: 0.5,
          ),
        ],
      );

      final meal = PlannedMealFactory.fromRecipe(
        recipe: recipe,
        servings: 3,
        date: DateTime(2026, 1, 5),
        meal: 'lunch',
        id: 'planned-1',
      );

      expect(meal.id, 'planned-1');
      expect(meal.name, 'Chicken Rice Bowl (3x)');
      expect(meal.recipeId, 'recipe-1');
      expect(meal.servings, 3);
      expect(meal.calories, closeTo(846, 0.0001));
      expect(meal.protein, closeTo(99.75, 0.0001));
      expect(meal.carbs, 75);
      expect(meal.fat, closeTo(11.25, 0.0001));
      expect(meal.ingredients.first.amount, 300);
      expect(meal.ingredients.first.category, ShoppingCategory.protein);
      expect(meal.ingredients.last.category, ShoppingCategory.grains);
    });

    test('builds a planned meal from extracted recipe data', () {
      final extraction = RecipeExtraction(
        recipeName: null,
        servings: 2,
        totalCalories: 600,
        totalProtein: 20,
        totalCarbs: 80,
        totalFat: 18,
        ingredients: [
          ExtractedIngredient(
            name: 'Yogurt',
            amount: 200,
            unit: 'g',
            category: ShoppingCategory.dairy,
          ),
        ],
      );

      final meal = PlannedMealFactory.fromExtractedRecipe(
        recipe: extraction,
        date: DateTime(2026, 1, 6),
        meal: 'breakfast',
        fallbackName: 'Scanned Recipe',
        id: 'planned-2',
      );

      expect(meal.id, 'planned-2');
      expect(meal.name, 'Scanned Recipe');
      expect(meal.calories, 300);
      expect(meal.protein, 10);
      expect(meal.carbs, 40);
      expect(meal.fat, 9);
      expect(meal.ingredients.single.category, ShoppingCategory.dairy);
    });

    test('builds a planned meal from a food item and infers category', () {
      const item = FoodItem(
        id: 'juice',
        name: 'Orange Juice',
        category: 'drink',
        caloriesPer100g: 45,
        proteinPer100g: 0.7,
        carbsPer100g: 10.4,
        fatPer100g: 0.2,
      );

      final meal = PlannedMealFactory.fromFoodItem(
        food: item,
        date: DateTime(2026, 1, 7),
        meal: 'snack',
        id: 'planned-3',
      );

      expect(meal.id, 'planned-3');
      expect(meal.name, 'Orange Juice');
      expect(meal.ingredients.single.category, ShoppingCategory.beverages);
      expect(meal.ingredients.single.unit, 'g');
      expect(meal.ingredients.single.amount, 100);
    });

    test('builds a manual planned meal with a default ingredient', () {
      final meal = PlannedMealFactory.manual(
        id: 'planned-4',
        date: DateTime(2026, 1, 8),
        meal: 'dinner',
        name: 'Homemade Soup',
        calories: 320,
        protein: 14,
        carbs: 28,
        fat: 12,
      );

      expect(meal.id, 'planned-4');
      expect(meal.ingredients.single.name, 'Homemade Soup');
      expect(meal.ingredients.single.unit, 'portion');
      expect(meal.ingredients.single.category, ShoppingCategory.other);
    });
  });
}
