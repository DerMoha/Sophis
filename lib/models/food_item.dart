import 'package:sophis/models/nutrition_totals.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/models/portion_selection.dart';
import 'package:sophis/models/serving_size.dart';

/// Food item template with nutrition per 100 [nutritionUnit].
class FoodItem {
  final String id;
  final String name;
  final String category;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final NutritionUnit nutritionUnit;
  final String? barcode;
  final String? brand;
  final String? imageUrl;
  final List<ServingSize> servings;
  final bool isFavorite;
  final PortionSelection? lastUsedPortion;

  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.fiberPer100g = 0,
    this.nutritionUnit = NutritionUnit.gram,
    this.barcode,
    this.brand,
    this.imageUrl,
    this.servings = const [],
    this.isFavorite = false,
    this.lastUsedPortion,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'caloriesPer100g': caloriesPer100g,
        'proteinPer100g': proteinPer100g,
        'carbsPer100g': carbsPer100g,
        'fatPer100g': fatPer100g,
        'fiberPer100g': fiberPer100g,
        'nutritionUnit': nutritionUnit.storageValue,
        'barcode': barcode,
        'brand': brand,
        'imageUrl': imageUrl,
        'servings': servings.map((s) => s.toJson()).toList(),
        'isFavorite': isFavorite,
        if (lastUsedPortion != null)
          'lastUsedPortion': lastUsedPortion!.toJson(),
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
        id: json['id'],
        name: json['name'],
        category: json['category'],
        caloriesPer100g: (json['caloriesPer100g'] as num).toDouble(),
        proteinPer100g: (json['proteinPer100g'] as num).toDouble(),
        carbsPer100g: (json['carbsPer100g'] as num).toDouble(),
        fatPer100g: (json['fatPer100g'] as num).toDouble(),
        fiberPer100g: (json['fiberPer100g'] as num?)?.toDouble() ?? 0,
        nutritionUnit: NutritionUnitX.fromStorage(
          json['nutritionUnit'] as String?,
        ),
        barcode: json['barcode'],
        brand: json['brand'],
        imageUrl: json['imageUrl'],
        servings: (json['servings'] as List?)
                ?.map((s) => ServingSize.fromJson(s as Map<String, dynamic>))
                .toList() ??
            const [],
        isFavorite: json['isFavorite'] as bool? ?? false,
        lastUsedPortion: json['lastUsedPortion'] is Map<String, dynamic>
            ? PortionSelection.fromJson(
                json['lastUsedPortion'] as Map<String, dynamic>,
              )
            : null,
      );

  /// Calculate nutrition for a specific amount in this food's basis unit.
  NutritionTotals calculateFor(double amount) => calculateForSelection(
        PortionSelection(amount: amount, unit: nutritionUnit),
      );

  /// Calculate nutrition while rejecting mismatched canonical units.
  NutritionTotals calculateForSelection(PortionSelection selection) {
    if (selection.unit != nutritionUnit) {
      throw ArgumentError.value(
        selection.unit,
        'selection.unit',
        'Food nutrition is expressed per ${nutritionUnit.symbol}',
      );
    }
    final factor = selection.amount / 100;
    return NutritionTotals(
      calories: caloriesPer100g * factor,
      protein: proteinPer100g * factor,
      carbs: carbsPer100g * factor,
      fat: fatPer100g * factor,
      fiber: fiberPer100g * factor,
    );
  }

  /// Create a copy with optional field overrides
  FoodItem copyWith({
    String? id,
    String? name,
    String? category,
    double? caloriesPer100g,
    double? proteinPer100g,
    double? carbsPer100g,
    double? fatPer100g,
    double? fiberPer100g,
    NutritionUnit? nutritionUnit,
    String? barcode,
    String? brand,
    String? imageUrl,
    List<ServingSize>? servings,
    bool? isFavorite,
    PortionSelection? lastUsedPortion,
  }) =>
      FoodItem(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
        proteinPer100g: proteinPer100g ?? this.proteinPer100g,
        carbsPer100g: carbsPer100g ?? this.carbsPer100g,
        fatPer100g: fatPer100g ?? this.fatPer100g,
        fiberPer100g: fiberPer100g ?? this.fiberPer100g,
        nutritionUnit: nutritionUnit ?? this.nutritionUnit,
        barcode: barcode ?? this.barcode,
        brand: brand ?? this.brand,
        imageUrl: imageUrl ?? this.imageUrl,
        servings: servings ?? this.servings,
        isFavorite: isFavorite ?? this.isFavorite,
        lastUsedPortion: lastUsedPortion ?? this.lastUsedPortion,
      );
}
