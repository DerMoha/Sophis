import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/models/portion_selection.dart';

/// User-defined portion preset for a specific product.
class CustomPortion {
  final String id;
  final String productKey; // barcode or normalized product name
  final String name;

  /// Canonical amount. Kept as `grams` for compatibility with the original
  /// persistence contract; [unit] is authoritative for new portions.
  final double grams;
  final NutritionUnit unit;
  final String? label;
  final double? quantity;
  final DateTime createdAt;

  const CustomPortion({
    required this.id,
    required this.productKey,
    required this.name,
    double? grams,
    double? amount,
    double? canonicalAmount,
    this.unit = NutritionUnit.gram,
    this.label,
    this.quantity,
    required this.createdAt,
  }) : grams = grams ?? amount ?? canonicalAmount ?? 0;

  double get amount => grams;

  double get canonicalAmount => grams;

  NutritionUnit get canonicalUnit => unit;

  String? get displayLabel => label;

  double? get displayQuantity => quantity;

  PortionSelection get selection => PortionSelection(
        amount: grams,
        unit: unit,
        humanLabel: label,
        labelQuantity: quantity,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'productKey': productKey,
        'name': name,
        'grams': grams,
        'unit': unit.storageValue,
        if (label != null) 'label': label,
        if (quantity != null) 'quantity': quantity,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CustomPortion.fromJson(Map<String, dynamic> json) => CustomPortion(
        id: json['id'] as String,
        productKey: json['productKey'] as String,
        name: json['name'] as String,
        grams: ((json['grams'] ?? json['amount']) as num).toDouble(),
        unit: NutritionUnitX.fromStorage(json['unit'] as String?),
        label: json['label'] as String?,
        quantity: (json['quantity'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  /// Create a unique product key from barcode or name
  static String createProductKey({String? barcode, required String name}) {
    if (barcode != null && barcode.isNotEmpty) {
      return 'barcode:$barcode';
    }
    return 'name:${name.toLowerCase().trim()}';
  }
}
