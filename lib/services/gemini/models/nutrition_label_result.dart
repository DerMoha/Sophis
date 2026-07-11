class NutritionLabelResult {
  final String? productName;
  final String? brand;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final double? servingSizeG;
  final String? servingName;

  const NutritionLabelResult({
    this.productName,
    this.brand,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.fiberPer100g = 0,
    this.servingSizeG,
    this.servingName,
  });

  NutritionLabelResult copyWith({
    String? productName,
    String? brand,
    double? caloriesPer100g,
    double? proteinPer100g,
    double? carbsPer100g,
    double? fatPer100g,
    double? fiberPer100g,
    double? servingSizeG,
    String? servingName,
  }) =>
      NutritionLabelResult(
        productName: productName ?? this.productName,
        brand: brand ?? this.brand,
        caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
        proteinPer100g: proteinPer100g ?? this.proteinPer100g,
        carbsPer100g: carbsPer100g ?? this.carbsPer100g,
        fatPer100g: fatPer100g ?? this.fatPer100g,
        fiberPer100g: fiberPer100g ?? this.fiberPer100g,
        servingSizeG: servingSizeG ?? this.servingSizeG,
        servingName: servingName ?? this.servingName,
      );
}
