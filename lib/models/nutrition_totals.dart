/// Typed nutrition data replacing `Map<String, double>`.
class NutritionTotals {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const NutritionTotals({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  static const zero = NutritionTotals();

  bool get isEmpty => calories == 0 && protein == 0 && carbs == 0 && fat == 0;

  NutritionTotals operator +(NutritionTotals other) {
    return NutritionTotals(
      calories: calories + other.calories,
      protein: protein + other.protein,
      carbs: carbs + other.carbs,
      fat: fat + other.fat,
    );
  }

  NutritionTotals operator *(double multiplier) {
    return NutritionTotals(
      calories: calories * multiplier,
      protein: protein * multiplier,
      carbs: carbs * multiplier,
      fat: fat * multiplier,
    );
  }

  /// Legacy map conversion for backward compatibility.
  Map<String, double> toMap() => {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };

  /// Create from legacy map format.
  factory NutritionTotals.fromMap(Map<String, double> map) {
    return NutritionTotals(
      calories: map['calories'] ?? 0,
      protein: map['protein'] ?? 0,
      carbs: map['carbs'] ?? 0,
      fat: map['fat'] ?? 0,
    );
  }

  @override
  String toString() => 'NutritionTotals(cal: ${calories.toStringAsFixed(0)}, '
      'P: ${protein.toStringAsFixed(0)}g, '
      'C: ${carbs.toStringAsFixed(0)}g, '
      'F: ${fat.toStringAsFixed(0)}g)';
}
