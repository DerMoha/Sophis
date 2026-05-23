/// Daily nutrition goals
class NutritionGoals {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;

  NutritionGoals({
    required this.calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
  })  : protein = protein ?? _defaultProtein(calories),
        carbs = carbs ?? _defaultCarbs(calories),
        fat = fat ?? _defaultFat(calories),
        fiber = fiber ?? _defaultFiber(calories);

  // Default macro split: 30% protein, 40% carbs, 30% fat, fiber ~14g per 1000cal
  static double _defaultProtein(double cal) => (cal * 0.30) / 4;
  static double _defaultCarbs(double cal) => (cal * 0.40) / 4;
  static double _defaultFat(double cal) => (cal * 0.30) / 9;
  static double _defaultFiber(double cal) => cal * 0.014;

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
      };

  factory NutritionGoals.fromJson(Map<String, dynamic> json) => NutritionGoals(
        calories: (json['calories'] as num).toDouble(),
        protein: (json['protein'] as num?)?.toDouble(),
        carbs: (json['carbs'] as num?)?.toDouble(),
        fat: (json['fat'] as num?)?.toDouble(),
        fiber: (json['fiber'] as num?)?.toDouble(),
      );

  NutritionGoals copyWith({
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
  }) =>
      NutritionGoals(
        calories: calories ?? this.calories,
        protein: protein ?? this.protein,
        carbs: carbs ?? this.carbs,
        fat: fat ?? this.fat,
        fiber: fiber ?? this.fiber,
      );
}
