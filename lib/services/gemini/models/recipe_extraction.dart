import 'package:sophis/services/gemini/models/extracted_ingredient.dart';

class RecipeExtraction {
  final String? recipeName;
  final int servings;
  final List<ExtractedIngredient> ingredients;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;

  RecipeExtraction({
    required this.recipeName,
    required this.servings,
    required this.ingredients,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
  });

  factory RecipeExtraction.empty() => RecipeExtraction(
        recipeName: null,
        servings: 0,
        ingredients: [],
        totalCalories: 0,
        totalProtein: 0,
        totalCarbs: 0,
        totalFat: 0,
      );

  bool get isEmpty => ingredients.isEmpty;
  bool get isNotEmpty => ingredients.isNotEmpty;

  double get caloriesPerServing => servings > 0 ? totalCalories / servings : 0;
  double get proteinPerServing => servings > 0 ? totalProtein / servings : 0;
  double get carbsPerServing => servings > 0 ? totalCarbs / servings : 0;
  double get fatPerServing => servings > 0 ? totalFat / servings : 0;
}
