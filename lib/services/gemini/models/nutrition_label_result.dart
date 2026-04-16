class NutritionLabelResult {
  final String? productName;
  final String? brand;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double? servingSizeG;
  final String? servingName;

  const NutritionLabelResult({
    this.productName,
    this.brand,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.servingSizeG,
    this.servingName,
  });
}
