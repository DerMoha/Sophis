/// A single planned meal for a specific day and meal slot
class PlannedMeal {
  final String id;
  final DateTime date;
  final String meal; // breakfast, lunch, dinner, snack
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String? recipeId; // If from a recipe
  final double servings; // Number of servings (for recipes)
  final List<PlannedMealIngredient> ingredients; // For shopping list

  const PlannedMeal({
    required this.id,
    required this.date,
    required this.meal,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.recipeId,
    this.servings = 1,
    this.ingredients = const [],
  });

  /// Normalized date (midnight) for comparison
  DateTime get normalizedDate => DateTime(date.year, date.month, date.day);

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'meal': meal,
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'recipeId': recipeId,
        'servings': servings,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
      };

  factory PlannedMeal.fromJson(Map<String, dynamic> json) => PlannedMeal(
        id: json['id'],
        date: DateTime.parse(json['date']),
        meal: json['meal'],
        name: json['name'],
        calories: (json['calories'] as num).toDouble(),
        protein: (json['protein'] as num).toDouble(),
        carbs: (json['carbs'] as num).toDouble(),
        fat: (json['fat'] as num).toDouble(),
        recipeId: json['recipeId'],
        servings: (json['servings'] as num?)?.toDouble() ?? 1,
        ingredients: (json['ingredients'] as List?)
                ?.map((i) => PlannedMealIngredient.fromJson(i))
                .toList() ??
            [],
      );

  PlannedMeal copyWith({
    DateTime? date,
    String? meal,
    String? name,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    String? recipeId,
    double? servings,
    List<PlannedMealIngredient>? ingredients,
  }) =>
      PlannedMeal(
        id: id,
        date: date ?? this.date,
        meal: meal ?? this.meal,
        name: name ?? this.name,
        calories: calories ?? this.calories,
        protein: protein ?? this.protein,
        carbs: carbs ?? this.carbs,
        fat: fat ?? this.fat,
        recipeId: recipeId ?? this.recipeId,
        servings: servings ?? this.servings,
        ingredients: ingredients ?? this.ingredients,
      );
}

/// Ingredient for a planned meal (used for shopping list generation)
class PlannedMealIngredient {
  final String name;
  final double amount;
  final String unit;
  final String category; // produce, dairy, protein, grains, pantry, other

  const PlannedMealIngredient({
    required this.name,
    required this.amount,
    required this.unit,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'unit': unit,
        'category': category,
      };

  factory PlannedMealIngredient.fromJson(Map<String, dynamic> json) =>
      PlannedMealIngredient(
        name: json['name'],
        amount: (json['amount'] as num).toDouble(),
        unit: json['unit'],
        category: json['category'] ?? 'other',
      );
}

/// Shopping list item (aggregated from planned meals)
class ShoppingListItem {
  final String name;
  final double totalAmount;
  final String unit;
  final String category;
  final bool isChecked;

  const ShoppingListItem({
    required this.name,
    required this.totalAmount,
    required this.unit,
    required this.category,
    this.isChecked = false,
  });

  ShoppingListItem copyWith({
    String? name,
    double? totalAmount,
    String? unit,
    String? category,
    bool? isChecked,
  }) =>
      ShoppingListItem(
        name: name ?? this.name,
        totalAmount: totalAmount ?? this.totalAmount,
        unit: unit ?? this.unit,
        category: category ?? this.category,
        isChecked: isChecked ?? this.isChecked,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'totalAmount': totalAmount,
        'unit': unit,
        'category': category,
        'isChecked': isChecked,
      };

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) =>
      ShoppingListItem(
        name: json['name'],
        totalAmount: (json['totalAmount'] as num).toDouble(),
        unit: json['unit'],
        category: json['category'],
        isChecked: json['isChecked'] ?? false,
      );
}

/// Categories for shopping list grouping
class ShoppingCategory {
  static const String produce = 'produce';
  static const String dairy = 'dairy';
  static const String protein = 'protein';
  static const String grains = 'grains';
  static const String pantry = 'pantry';
  static const String frozen = 'frozen';
  static const String beverages = 'beverages';
  static const String other = 'other';

  static List<String> get all => [
        produce,
        dairy,
        protein,
        grains,
        pantry,
        frozen,
        beverages,
        other,
      ];

  static String getDisplayName(String category) {
    switch (category) {
      case produce:
        return 'Produce';
      case dairy:
        return 'Dairy';
      case protein:
        return 'Protein';
      case grains:
        return 'Grains & Bread';
      case pantry:
        return 'Pantry';
      case frozen:
        return 'Frozen';
      case beverages:
        return 'Beverages';
      default:
        return 'Other';
    }
  }

  static String getIcon(String category) {
    switch (category) {
      case produce:
        return '🥬';
      case dairy:
        return '🥛';
      case protein:
        return '🥩';
      case grains:
        return '🍞';
      case pantry:
        return '🥫';
      case frozen:
        return '🧊';
      case beverages:
        return '🥤';
      default:
        return '📦';
    }
  }
}
