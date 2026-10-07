import 'package:sophis/models/nutrition_unit.dart';

/// A portion selected by the user, with an explicit canonical amount.
///
/// Human labels are display metadata only. Calculations always use [amount]
/// and [unit], so a piece or package can never silently be interpreted as a
/// gram amount.
class PortionSelection {
  final double amount;
  final NutritionUnit unit;
  final String? humanLabel;
  final double? labelQuantity;

  const PortionSelection({
    double? amount,
    NutritionUnit? unit,
    double? canonicalAmount,
    NutritionUnit? canonicalUnit,
    this.humanLabel,
    this.labelQuantity,
  })  : amount = amount ?? canonicalAmount ?? 0,
        unit = unit ?? canonicalUnit ?? NutritionUnit.gram;

  double get canonicalAmount => amount;

  NutritionUnit get canonicalUnit => unit;

  bool get isValid => amount > 0 && amount.isFinite;

  PortionSelection copyWith({
    double? amount,
    NutritionUnit? unit,
    String? humanLabel,
    double? labelQuantity,
  }) =>
      PortionSelection(
        amount: amount ?? this.amount,
        unit: unit ?? this.unit,
        humanLabel: humanLabel ?? this.humanLabel,
        labelQuantity: labelQuantity ?? this.labelQuantity,
      );

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'unit': unit.storageValue,
        if (humanLabel != null) 'humanLabel': humanLabel,
        if (labelQuantity != null) 'labelQuantity': labelQuantity,
      };

  factory PortionSelection.fromJson(Map<String, dynamic> json) {
    final amount = (json['amount'] ?? json['grams']) as num?;
    if (amount == null) {
      throw const FormatException('Portion amount is missing');
    }
    return PortionSelection(
      amount: amount.toDouble(),
      unit: NutritionUnitX.fromStorage(json['unit'] as String?),
      humanLabel: json['humanLabel'] as String? ?? json['label'] as String?,
      labelQuantity:
          ((json['labelQuantity'] ?? json['quantity']) as num?)?.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PortionSelection &&
          amount == other.amount &&
          unit == other.unit &&
          humanLabel == other.humanLabel &&
          labelQuantity == other.labelQuantity;

  @override
  int get hashCode => Object.hash(amount, unit, humanLabel, labelQuantity);
}
