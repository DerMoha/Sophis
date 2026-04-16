class FoodAnalysis {
  final String name;
  final double portionGrams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  FoodAnalysis({
    required this.name,
    required this.portionGrams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  String get displayName => name;
  String get portionDisplay => '${portionGrams.toStringAsFixed(0)}g';
  String get caloriesDisplay => '${calories.toStringAsFixed(0)} kcal';
  String get macrosDisplay =>
      'P: ${protein.toStringAsFixed(0)}g | C: ${carbs.toStringAsFixed(0)}g | F: ${fat.toStringAsFixed(0)}g';

  FoodAnalysis copyWith({
    String? name,
    double? portionGrams,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
  }) {
    return FoodAnalysis(
      name: name ?? this.name,
      portionGrams: portionGrams ?? this.portionGrams,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
    );
  }

  FoodAnalysis scaledToPortion(double newPortionGrams) {
    if (portionGrams == 0) return this;
    final ratio = newPortionGrams / portionGrams;
    return copyWith(
      portionGrams: newPortionGrams,
      calories: calories * ratio,
      protein: protein * ratio,
      carbs: carbs * ratio,
      fat: fat * ratio,
    );
  }
}
