/// Logged food entry with timestamp
class FoodEntry {
  final String id;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime timestamp;
  final String meal; // breakfast, lunch, dinner, snack

  const FoodEntry({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.timestamp,
    required this.meal,
  });

  /// Create a copy with updated fields
  FoodEntry copyWith({
    String? id,
    String? name,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    DateTime? timestamp,
    String? meal,
  }) {
    return FoodEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      timestamp: timestamp ?? this.timestamp,
      meal: meal ?? this.meal,
    );
  }

  /// Scale all macros by a factor (used for portion adjustment)
  FoodEntry scaledBy(double factor) {
    return copyWith(
      calories: calories * factor,
      protein: protein * factor,
      carbs: carbs * factor,
      fat: fat * factor,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'timestamp': timestamp.toIso8601String(),
    'meal': meal,
  };

  factory FoodEntry.fromJson(Map<String, dynamic> json) => FoodEntry(
    id: json['id'],
    name: json['name'],
    calories: (json['calories'] as num).toDouble(),
    protein: (json['protein'] as num).toDouble(),
    carbs: (json['carbs'] as num).toDouble(),
    fat: (json['fat'] as num).toDouble(),
    timestamp: DateTime.parse(json['timestamp']),
    meal: json['meal'] ?? 'snack',
  );
}
