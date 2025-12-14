/// Recipe ingredient
class RecipeIngredient {
  final String id;
  final String name;
  final double amountGrams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const RecipeIngredient({
    required this.id,
    required this.name,
    required this.amountGrams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amountGrams': amountGrams,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) => RecipeIngredient(
    id: json['id'],
    name: json['name'],
    amountGrams: (json['amountGrams'] as num).toDouble(),
    calories: (json['calories'] as num).toDouble(),
    protein: (json['protein'] as num).toDouble(),
    carbs: (json['carbs'] as num).toDouble(),
    fat: (json['fat'] as num).toDouble(),
  );
}

/// Saved recipe with ingredients
class Recipe {
  final String id;
  final String name;
  final List<RecipeIngredient> ingredients;
  final int servings;
  final String? notes;
  final DateTime createdAt;

  const Recipe({
    required this.id,
    required this.name,
    required this.ingredients,
    this.servings = 1,
    this.notes,
    required this.createdAt,
  });

  /// Total nutrition for entire recipe
  Map<String, double> get totalNutrients {
    double cal = 0, prot = 0, carb = 0, fat = 0;
    for (final i in ingredients) {
      cal += i.calories;
      prot += i.protein;
      carb += i.carbs;
      fat += i.fat;
    }
    return {'calories': cal, 'protein': prot, 'carbs': carb, 'fat': fat};
  }

  /// Nutrition per serving
  Map<String, double> get nutrientsPerServing {
    final total = totalNutrients;
    return {
      'calories': total['calories']! / servings,
      'protein': total['protein']! / servings,
      'carbs': total['carbs']! / servings,
      'fat': total['fat']! / servings,
    };
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
    'servings': servings,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
    id: json['id'],
    name: json['name'],
    ingredients: (json['ingredients'] as List)
        .map((i) => RecipeIngredient.fromJson(i))
        .toList(),
    servings: json['servings'] ?? 1,
    notes: json['notes'],
    createdAt: DateTime.parse(json['createdAt']),
  );

  Recipe copyWith({
    String? name,
    List<RecipeIngredient>? ingredients,
    int? servings,
    String? notes,
  }) => Recipe(
    id: id,
    name: name ?? this.name,
    ingredients: ingredients ?? this.ingredients,
    servings: servings ?? this.servings,
    notes: notes ?? this.notes,
    createdAt: createdAt,
  );
}
