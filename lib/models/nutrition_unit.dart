/// The canonical unit used by nutrition values and portion selections.
enum NutritionUnit {
  gram,
  milliliter,
}

extension NutritionUnitX on NutritionUnit {
  /// Short unit shown next to an amount in the UI.
  String get symbol => switch (this) {
        NutritionUnit.gram => 'g',
        NutritionUnit.milliliter => 'ml',
      };

  /// Stable value used by JSON, Drift, and sync payloads.
  String get storageValue => switch (this) {
        NutritionUnit.gram => 'gram',
        NutritionUnit.milliliter => 'milliliter',
      };

  static NutritionUnit fromStorage(String? value) => switch (value) {
        'milliliter' || 'ml' => NutritionUnit.milliliter,
        _ => NutritionUnit.gram,
      };
}
