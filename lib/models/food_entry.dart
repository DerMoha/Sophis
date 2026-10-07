import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/models/portion_selection.dart';

/// Logged food entry with timestamp
class FoodEntry {
  final String id;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final DateTime timestamp;
  final String meal; // breakfast, lunch, dinner, snack
  final String? sourceFoodId;
  final double? portionAmount;
  final NutritionUnit? portionUnit;
  final String? portionLabel;
  final double? portionQuantity;

  const FoodEntry({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
    required this.timestamp,
    required this.meal,
    this.sourceFoodId,
    this.portionAmount,
    this.portionUnit,
    this.portionLabel,
    this.portionQuantity,
  });

  PortionSelection? get portionSelection {
    final amount = portionAmount;
    final unit = portionUnit;
    if (amount == null || unit == null) return null;
    return PortionSelection(
      amount: amount,
      unit: unit,
      humanLabel: portionLabel,
      labelQuantity: portionQuantity,
    );
  }

  double? get canonicalAmount => portionAmount;

  NutritionUnit? get canonicalUnit => portionUnit;

  String? get displayLabel => portionLabel;

  double? get displayQuantity => portionQuantity;

  String get displayPortionText {
    final selection = portionSelection;
    if (selection == null) return '';
    final canonical =
        '${_formatNumber(selection.amount)}${selection.unit.symbol}';
    final label = selection.humanLabel;
    if (label == null || label.trim().isEmpty) return canonical;
    final quantity = selection.labelQuantity;
    final displayQuantity =
        quantity == null ? '' : '${_formatNumber(quantity)} ';
    return '$displayQuantity$label ($canonical)';
  }

  /// Create a copy with updated fields
  FoodEntry copyWith({
    String? id,
    String? name,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    DateTime? timestamp,
    String? meal,
    String? sourceFoodId,
    double? portionAmount,
    NutritionUnit? portionUnit,
    String? portionLabel,
    double? portionQuantity,
  }) {
    return FoodEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      timestamp: timestamp ?? this.timestamp,
      meal: meal ?? this.meal,
      sourceFoodId: sourceFoodId ?? this.sourceFoodId,
      portionAmount: portionAmount ?? this.portionAmount,
      portionUnit: portionUnit ?? this.portionUnit,
      portionLabel: portionLabel ?? this.portionLabel,
      portionQuantity: portionQuantity ?? this.portionQuantity,
    );
  }

  /// Scale all macros by a factor (used for portion adjustment)
  FoodEntry scaledBy(double factor) {
    final scaled = copyWith(
      calories: calories * factor,
      protein: protein * factor,
      carbs: carbs * factor,
      fat: fat * factor,
      fiber: fiber * factor,
      portionAmount: portionAmount == null ? null : portionAmount! * factor,
      portionQuantity:
          portionQuantity == null ? null : portionQuantity! * factor,
    );
    if (portionSelection == null) return scaled;

    final replacement = scaled.displayPortionText;
    final oldSuffix = ' ($displayPortionText)';
    final updatedName = name.endsWith(oldSuffix)
        ? '${name.substring(0, name.length - oldSuffix.length)} ($replacement)'
        : name.replaceFirst(
            RegExp(r'\s*\([^)]*\)\s*$'),
            ' ($replacement)',
          );
    return scaled.copyWith(
      name: updatedName == name ? '$name ($replacement)' : updatedName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'timestamp': timestamp.toIso8601String(),
        'meal': meal,
        if (sourceFoodId != null) 'sourceFoodId': sourceFoodId,
        if (portionAmount != null) 'portionAmount': portionAmount,
        if (portionUnit != null) 'portionUnit': portionUnit!.storageValue,
        if (portionLabel != null) 'portionLabel': portionLabel,
        if (portionQuantity != null) 'portionQuantity': portionQuantity,
      };

  factory FoodEntry.fromJson(Map<String, dynamic> json) => FoodEntry(
        id: json['id'],
        name: json['name'],
        calories: (json['calories'] as num).toDouble(),
        protein: (json['protein'] as num).toDouble(),
        carbs: (json['carbs'] as num).toDouble(),
        fat: (json['fat'] as num).toDouble(),
        fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
        timestamp: DateTime.parse(json['timestamp']),
        meal: json['meal'] ?? 'snack',
        sourceFoodId: json['sourceFoodId'] as String?,
        portionAmount: (json['portionAmount'] as num?)?.toDouble(),
        portionUnit: json['portionUnit'] == null
            ? null
            : NutritionUnitX.fromStorage(json['portionUnit'] as String),
        portionLabel: json['portionLabel'] as String?,
        portionQuantity: (json['portionQuantity'] as num?)?.toDouble(),
      );

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }
}
