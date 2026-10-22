import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';

/// Editable, intentionally nullable output from a nutrition-label reader.
///
/// A missing value is different from a printed zero. Keeping that distinction
/// lets the review UI ask for only the fields the reader could not establish.
class NutritionLabelDraft {
  final String? productName;
  final String? brand;
  final double? caloriesPer100;
  final double? proteinPer100;
  final double? carbsPer100;
  final double? fatPer100;
  final double? fiberPer100;
  final NutritionUnit nutritionUnit;
  final double? servingAmount;
  final String? servingName;
  final bool wasServingConverted;
  final NutritionLabelAnalysisSource analysisSource;
  final Set<NutritionLabelField> upperBoundFields;

  const NutritionLabelDraft({
    this.productName,
    this.brand,
    this.caloriesPer100,
    this.proteinPer100,
    this.carbsPer100,
    this.fatPer100,
    this.fiberPer100,
    this.nutritionUnit = NutritionUnit.gram,
    this.servingAmount,
    this.servingName,
    this.wasServingConverted = false,
    this.analysisSource = NutritionLabelAnalysisSource.localOcr,
    this.upperBoundFields = const {},
  });

  bool get hasAnyNutrition =>
      caloriesPer100 != null ||
      proteinPer100 != null ||
      carbsPer100 != null ||
      fatPer100 != null ||
      fiberPer100 != null;

  bool get hasRequiredNutrition =>
      caloriesPer100 != null &&
      proteinPer100 != null &&
      carbsPer100 != null &&
      fatPer100 != null;

  NutritionLabelResult? toResult() {
    if (!hasRequiredNutrition) return null;
    return NutritionLabelResult(
      productName: productName,
      brand: brand,
      caloriesPer100g: caloriesPer100!,
      proteinPer100g: proteinPer100!,
      carbsPer100g: carbsPer100!,
      fatPer100g: fatPer100!,
      fiberPer100g: fiberPer100 ?? 0,
      nutritionUnit: nutritionUnit,
      servingSizeG: servingAmount,
      servingName: servingName,
      wasServingConverted: wasServingConverted,
      upperBoundFields: upperBoundFields,
      presentFields: {
        NutritionLabelField.calories,
        NutritionLabelField.protein,
        NutritionLabelField.carbs,
        NutritionLabelField.fat,
        if (fiberPer100 != null) NutritionLabelField.fiber,
      },
    );
  }

  factory NutritionLabelDraft.fromResult(NutritionLabelResult result) {
    return NutritionLabelDraft(
      productName: result.productName,
      brand: result.brand,
      caloriesPer100:
          result.presentFields.contains(NutritionLabelField.calories)
              ? result.caloriesPer100g
              : null,
      proteinPer100: result.presentFields.contains(NutritionLabelField.protein)
          ? result.proteinPer100g
          : null,
      carbsPer100: result.presentFields.contains(NutritionLabelField.carbs)
          ? result.carbsPer100g
          : null,
      fatPer100: result.presentFields.contains(NutritionLabelField.fat)
          ? result.fatPer100g
          : null,
      fiberPer100: result.presentFields.contains(NutritionLabelField.fiber)
          ? result.fiberPer100g
          : null,
      nutritionUnit: result.nutritionUnit,
      servingAmount: result.servingSizeG,
      servingName: result.servingName,
      wasServingConverted: result.wasServingConverted,
      upperBoundFields: result.upperBoundFields,
    );
  }

  NutritionLabelDraft copyWith({
    String? productName,
    String? brand,
    double? caloriesPer100,
    double? proteinPer100,
    double? carbsPer100,
    double? fatPer100,
    double? fiberPer100,
    NutritionUnit? nutritionUnit,
    double? servingAmount,
    String? servingName,
    bool? wasServingConverted,
    NutritionLabelAnalysisSource? analysisSource,
    Set<NutritionLabelField>? upperBoundFields,
  }) {
    return NutritionLabelDraft(
      productName: productName ?? this.productName,
      brand: brand ?? this.brand,
      caloriesPer100: caloriesPer100 ?? this.caloriesPer100,
      proteinPer100: proteinPer100 ?? this.proteinPer100,
      carbsPer100: carbsPer100 ?? this.carbsPer100,
      fatPer100: fatPer100 ?? this.fatPer100,
      fiberPer100: fiberPer100 ?? this.fiberPer100,
      nutritionUnit: nutritionUnit ?? this.nutritionUnit,
      servingAmount: servingAmount ?? this.servingAmount,
      servingName: servingName ?? this.servingName,
      wasServingConverted: wasServingConverted ?? this.wasServingConverted,
      analysisSource: analysisSource ?? this.analysisSource,
      upperBoundFields: upperBoundFields ?? this.upperBoundFields,
    );
  }

  Map<String, dynamic> toJson() => {
        if (productName != null) 'productName': productName,
        if (brand != null) 'brand': brand,
        if (caloriesPer100 != null) 'caloriesPer100': caloriesPer100,
        if (proteinPer100 != null) 'proteinPer100': proteinPer100,
        if (carbsPer100 != null) 'carbsPer100': carbsPer100,
        if (fatPer100 != null) 'fatPer100': fatPer100,
        if (fiberPer100 != null) 'fiberPer100': fiberPer100,
        'nutritionUnit': nutritionUnit.storageValue,
        'analysisSource': analysisSource.name,
        'wasServingConverted': wasServingConverted,
        if (upperBoundFields.isNotEmpty)
          'upperBoundFields':
              upperBoundFields.map((field) => field.name).toList(),
        if (servingAmount != null) 'servingAmount': servingAmount,
        if (servingName != null) 'servingName': servingName,
      };

  factory NutritionLabelDraft.fromJson(Map<String, dynamic> json) {
    double? number(Object? value) {
      if (value is num) return value.toDouble();
      if (value is! String) return null;

      var raw = value.trim().replaceAll(RegExp(r'[\s\u00a0]'), '');
      if (raw.contains(',') && raw.contains('.')) {
        final decimalSeparator =
            raw.lastIndexOf(',') > raw.lastIndexOf('.') ? ',' : '.';
        final decimalIndex = raw.lastIndexOf(decimalSeparator);
        raw =
            '${raw.substring(0, decimalIndex).replaceAll(RegExp(r'[.,]'), '')}.${raw.substring(decimalIndex + 1)}';
      } else {
        raw = raw.replaceAll(',', '.');
      }
      return double.tryParse(raw);
    }

    final sourceName = json['analysisSource'] as String?;
    final analysisSource = NutritionLabelAnalysisSource.values.firstWhere(
      (source) => source.name == sourceName,
      orElse: () => NutritionLabelAnalysisSource.localOcr,
    );
    return NutritionLabelDraft(
      productName: json['productName'] as String?,
      brand: json['brand'] as String?,
      caloriesPer100: number(json['caloriesPer100']),
      proteinPer100: number(json['proteinPer100']),
      carbsPer100: number(json['carbsPer100']),
      fatPer100: number(json['fatPer100']),
      fiberPer100: number(json['fiberPer100']),
      nutritionUnit: NutritionUnitX.fromStorage(
        json['nutritionUnit'] as String?,
      ),
      servingAmount: number(json['servingAmount']),
      servingName: json['servingName'] as String?,
      wasServingConverted: json['wasServingConverted'] as bool? ?? false,
      analysisSource: analysisSource,
      upperBoundFields: {
        for (final field in NutritionLabelField.values)
          if ((json['upperBoundFields'] as List<dynamic>?)
                  ?.contains(field.name) ??
              false)
            field,
      },
    );
  }
}
