import 'package:uuid/uuid.dart';

import '../models/food_item.dart';
import '../models/meal_plan.dart';
import '../models/recipe.dart';
import 'gemini_food_service.dart';

class PlannedMealFactory {
  static const Uuid _uuid = Uuid();

  static PlannedMeal fromExtractedRecipe({
    required RecipeExtraction recipe,
    required DateTime date,
    required String meal,
    String fallbackName = 'Scanned Recipe',
    String? id,
  }) {
    final ingredients = recipe.ingredients
        .map(
          (ingredient) => PlannedMealIngredient(
            name: ingredient.name,
            amount: ingredient.amount,
            unit: ingredient.unit,
            category: ingredient.category,
          ),
        )
        .toList();

    return PlannedMeal(
      id: id ?? _uuid.v4(),
      date: date,
      meal: meal,
      name: recipe.recipeName ?? fallbackName,
      calories: recipe.caloriesPerServing,
      protein: recipe.proteinPerServing,
      carbs: recipe.carbsPerServing,
      fat: recipe.fatPerServing,
      servings: 1,
      ingredients: ingredients,
    );
  }

  static PlannedMeal fromRecipe({
    required Recipe recipe,
    required int servings,
    required DateTime date,
    required String meal,
    String? id,
  }) {
    final nutrients = recipe.nutrientsPerServing;
    final ingredients = recipe.ingredients
        .map(
          (ingredient) => PlannedMealIngredient(
            name: ingredient.name,
            amount: (ingredient.amountGrams * servings) / recipe.servings,
            unit: 'g',
            category: inferCategory(ingredient.name),
          ),
        )
        .toList();

    return PlannedMeal(
      id: id ?? _uuid.v4(),
      date: date,
      meal: meal,
      name: '${recipe.name} (${servings}x)',
      calories: nutrients.calories * servings,
      protein: nutrients.protein * servings,
      carbs: nutrients.carbs * servings,
      fat: nutrients.fat * servings,
      recipeId: recipe.id,
      servings: servings.toDouble(),
      ingredients: ingredients,
    );
  }

  static PlannedMeal fromFoodItem({
    required FoodItem food,
    required DateTime date,
    required String meal,
    String? id,
  }) {
    return PlannedMeal(
      id: id ?? _uuid.v4(),
      date: date,
      meal: meal,
      name: food.name,
      calories: food.caloriesPer100g,
      protein: food.proteinPer100g,
      carbs: food.carbsPer100g,
      fat: food.fatPer100g,
      ingredients: [
        PlannedMealIngredient(
          name: food.name,
          amount: 100,
          unit: 'g',
          category: inferCategory(food.name),
        ),
      ],
    );
  }

  static PlannedMeal manual({
    required DateTime date,
    required String meal,
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    String ingredientUnit = 'portion',
    String ingredientCategory = ShoppingCategory.other,
    double ingredientAmount = 1,
    String? id,
  }) {
    return PlannedMeal(
      id: id ?? _uuid.v4(),
      date: date,
      meal: meal,
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      ingredients: [
        PlannedMealIngredient(
          name: name,
          amount: ingredientAmount,
          unit: ingredientUnit,
          category: ingredientCategory,
        ),
      ],
    );
  }

  static String inferCategory(String name) {
    final lower = name.toLowerCase();
    if (_matchesAny(lower, [
      'chicken',
      'beef',
      'pork',
      'fish',
      'salmon',
      'tuna',
      'egg',
      'meat',
      'turkey',
    ])) {
      return ShoppingCategory.protein;
    }
    if (_matchesAny(lower, ['milk', 'cheese', 'yogurt', 'butter', 'cream'])) {
      return ShoppingCategory.dairy;
    }
    if (_matchesAny(lower, ['water', 'juice', 'soda', 'coffee', 'tea'])) {
      return ShoppingCategory.beverages;
    }
    if (_matchesAny(lower, [
      'apple',
      'banana',
      'orange',
      'tomato',
      'lettuce',
      'carrot',
      'onion',
      'garlic',
      'vegetable',
      'fruit',
    ])) {
      return ShoppingCategory.produce;
    }
    if (_matchesAny(
      lower,
      ['bread', 'rice', 'pasta', 'oat', 'cereal', 'flour'],
    )) {
      return ShoppingCategory.grains;
    }
    if (_matchesAny(lower, ['frozen', 'ice cream'])) {
      return ShoppingCategory.frozen;
    }
    return ShoppingCategory.pantry;
  }

  static bool _matchesAny(String text, List<String> keywords) {
    return keywords.any(text.contains);
  }
}
