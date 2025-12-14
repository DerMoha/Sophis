/// Daily nutrition goals
class NutritionGoals {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  NutritionGoals({
    required this.calories,
    double? protein,
    double? carbs,
    double? fat,
  })  : protein = protein ?? _defaultProtein(calories),
        carbs = carbs ?? _defaultCarbs(calories),
        fat = fat ?? _defaultFat(calories);

  // Default macro split: 30% protein, 40% carbs, 30% fat
  static double _defaultProtein(double cal) => (cal * 0.30) / 4;
  static double _defaultCarbs(double cal) => (cal * 0.40) / 4;
  static double _defaultFat(double cal) => (cal * 0.30) / 9;

  Map<String, dynamic> toJson() => {
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };

  factory NutritionGoals.fromJson(Map<String, dynamic> json) => NutritionGoals(
    calories: (json['calories'] as num).toDouble(),
    protein: (json['protein'] as num?)?.toDouble(),
    carbs: (json['carbs'] as num?)?.toDouble(),
    fat: (json['fat'] as num?)?.toDouble(),
  );

  NutritionGoals copyWith({
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
  }) => NutritionGoals(
    calories: calories ?? this.calories,
    protein: protein ?? this.protein,
    carbs: carbs ?? this.carbs,
    fat: fat ?? this.fat,
  );
}
