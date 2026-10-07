import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/models/portion_selection.dart';

/// Represents a serving size option for a food item.
class ServingSize {
  final String name;

  /// Canonical amount. Kept as `grams` for source compatibility with older
  /// callers and JSON; [unit] makes the meaning explicit for new data.
  final double grams;
  final NutritionUnit unit;
  final double multiplier;
  final bool isCustom;
  final String? label;
  final double? quantity;

  const ServingSize({
    required this.name,
    double? grams,
    double? amount,
    double? canonicalAmount,
    this.unit = NutritionUnit.gram,
    this.multiplier = 1.0,
    this.isCustom = false,
    this.label,
    this.quantity,
  }) : grams = grams ?? amount ?? canonicalAmount ?? 0;

  double get amount => grams;

  String? get humanLabel => label;

  double? get labelQuantity => quantity;

  PortionSelection get selection => PortionSelection(
        amount: grams,
        unit: unit,
        humanLabel: label,
        labelQuantity: quantity,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'grams': grams,
        'unit': unit.storageValue,
        'multiplier': multiplier,
        'isCustom': isCustom,
        if (label != null) 'label': label,
        if (quantity != null) 'quantity': quantity,
      };

  factory ServingSize.fromJson(Map<String, dynamic> json) => ServingSize(
        name: json['name'] as String,
        grams: ((json['grams'] ?? json['amount']) as num).toDouble(),
        unit: NutritionUnitX.fromStorage(json['unit'] as String?),
        multiplier: (json['multiplier'] as num?)?.toDouble() ?? 1.0,
        isCustom: json['isCustom'] as bool? ?? false,
        label: json['label'] as String?,
        quantity: (json['quantity'] as num?)?.toDouble(),
      );

  /// Generate fractional serving options from a base serving
  static List<ServingSize> generateFractions(
    String baseName,
    double baseGrams, {
    NutritionUnit unit = NutritionUnit.gram,
  }) {
    final multipliers = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0];
    final fractionNames = {
      0.25: '1/4',
      0.5: '1/2',
      0.75: '3/4',
      1.0: '1',
      1.5: '1.5',
      2.0: '2',
    };

    return multipliers.map((m) {
      final displayName = '${fractionNames[m]} $baseName';
      return ServingSize(
        name: displayName,
        grams: baseGrams * m,
        unit: unit,
        multiplier: m,
        label: baseName,
        quantity: m,
      );
    }).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServingSize &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          grams == other.grams &&
          unit == other.unit &&
          label == other.label &&
          quantity == other.quantity;

  @override
  int get hashCode => Object.hash(name, grams, unit, label, quantity);
}
