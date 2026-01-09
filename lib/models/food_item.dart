import 'serving_size.dart';

/// Food item template with nutrition per 100g
class FoodItem {
  final String id;
  final String name;
  final String category;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final String? barcode;
  final String? brand;
  final String? imageUrl;
  final List<ServingSize> servings;

  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.barcode,
    this.brand,
    this.imageUrl,
    this.servings = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'caloriesPer100g': caloriesPer100g,
        'proteinPer100g': proteinPer100g,
        'carbsPer100g': carbsPer100g,
        'fatPer100g': fatPer100g,
        'barcode': barcode,
        'brand': brand,
        'imageUrl': imageUrl,
        'servings': servings.map((s) => s.toJson()).toList(),
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        id: json['id'],
        name: json['name'],
        category: json['category'],
        caloriesPer100g: (json['caloriesPer100g'] as num).toDouble(),
        proteinPer100g: (json['proteinPer100g'] as num).toDouble(),
        carbsPer100g: (json['carbsPer100g'] as num).toDouble(),
        fatPer100g: (json['fatPer100g'] as num).toDouble(),
        barcode: json['barcode'],
        brand: json['brand'],
        imageUrl: json['imageUrl'],
        servings: (json['servings'] as List?)
                ?.map((s) => ServingSize.fromJson(s as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  /// Calculate nutrition for a specific amount
  Map<String, double> calculateFor(double grams) {
    final factor = grams / 100;
    return {
      'calories': caloriesPer100g * factor,
      'protein': proteinPer100g * factor,
      'carbs': carbsPer100g * factor,
      'fat': fatPer100g * factor,
    };
  }
}
