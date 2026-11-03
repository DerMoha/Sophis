import 'package:sophis/models/nutrition_unit.dart';

enum NutritionLabelAnalysisSource { localOcr, gemini, cloudAi }

enum NutritionLabelField { calories, protein, carbs, fat, fiber }

const Set<NutritionLabelField> _allNutritionLabelFields = {
  NutritionLabelField.calories,
  NutritionLabelField.protein,
  NutritionLabelField.carbs,
  NutritionLabelField.fat,
  NutritionLabelField.fiber,
};

const Set<NutritionLabelField> requiredNutritionLabelFields = {
  NutritionLabelField.calories,
  NutritionLabelField.protein,
  NutritionLabelField.carbs,
  NutritionLabelField.fat,
};

class NutritionLabelResult {
  final String? productName;
  final String? brand;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final NutritionUnit nutritionUnit;
  final double? servingSizeG;
  final String? servingName;
  final bool wasServingConverted;
  final Set<NutritionLabelField> presentFields;
  final Set<NutritionLabelField> upperBoundFields;

  /// OCR evidence only: selected numeric cells with a printed unit.
  final Set<NutritionLabelField> explicitUnitFields;

  const NutritionLabelResult({
    this.productName,
    this.brand,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.fiberPer100g = 0,
    this.nutritionUnit = NutritionUnit.gram,
    this.servingSizeG,
    this.servingName,
    this.wasServingConverted = false,
    this.presentFields = _allNutritionLabelFields,
    this.upperBoundFields = const {},
    this.explicitUnitFields = const {},
  });

  bool get hasRequiredNutrition =>
      presentFields.containsAll(requiredNutritionLabelFields);

  NutritionLabelResult copyWith({
    String? productName,
    String? brand,
    bool clearProductName = false,
    bool clearBrand = false,
    double? caloriesPer100g,
    double? proteinPer100g,
    double? carbsPer100g,
    double? fatPer100g,
    double? fiberPer100g,
    NutritionUnit? nutritionUnit,
    double? servingSizeG,
    String? servingName,
    bool? wasServingConverted,
    Set<NutritionLabelField>? presentFields,
    Set<NutritionLabelField>? upperBoundFields,
    Set<NutritionLabelField>? explicitUnitFields,
  }) =>
      NutritionLabelResult(
        productName: clearProductName ? null : productName ?? this.productName,
        brand: clearBrand ? null : brand ?? this.brand,
        caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
        proteinPer100g: proteinPer100g ?? this.proteinPer100g,
        carbsPer100g: carbsPer100g ?? this.carbsPer100g,
        fatPer100g: fatPer100g ?? this.fatPer100g,
        fiberPer100g: fiberPer100g ?? this.fiberPer100g,
        nutritionUnit: nutritionUnit ?? this.nutritionUnit,
        servingSizeG: servingSizeG ?? this.servingSizeG,
        servingName: servingName ?? this.servingName,
        wasServingConverted: wasServingConverted ?? this.wasServingConverted,
        presentFields: presentFields ?? this.presentFields,
        upperBoundFields: upperBoundFields ?? this.upperBoundFields,
        explicitUnitFields: explicitUnitFields ?? this.explicitUnitFields,
      );
}
