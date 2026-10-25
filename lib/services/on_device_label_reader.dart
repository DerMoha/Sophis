import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';

/// Reads per-100 values from OCR text with Apple's on-device model (iOS 26+
/// with Apple Intelligence). Used only when the table and line readers fail.
///
/// The model is good at pairing garbled or multilingual rows but can invent
/// numbers, so every value it returns must appear in the OCR text. Anything
/// else is dropped.
class OnDeviceLabelReader {
  const OnDeviceLabelReader();

  static const _channel = MethodChannel('sophis/nutrition_text');
  static const _timeout = Duration(seconds: 15);

  Future<NutritionLabelResult?> read(String ocrText) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        ocrText.trim().isEmpty) {
      return null;
    }
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'interpretLabel',
        {'text': ocrText},
      ).timeout(_timeout);
      if (raw?['status'] != 'ok') {
        debugPrint('On-device label reader: ${raw?['status']} '
            '${raw?['reason'] ?? ''}');
        return null;
      }
      return fromValues(
        (raw!['values'] as Map).cast<String, Object?>(),
        ocrText,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint('On-device label reader unavailable: ${error.code}');
      return null;
    } on TimeoutException {
      return null;
    }
  }

  /// Keeps only values printed in [ocrText] with their unit (`5,0 g`,
  /// `g 5,0`, `87 kcal`, `kcal 87`, `918/216` after `kJ/kcal`). A bare number
  /// is not enough: digits like 0 or 1 appear on almost every package.
  /// Returns null when nothing survives.
  @visibleForTesting
  static NutritionLabelResult? fromValues(
    Map<String, Object?> values,
    String ocrText,
  ) {
    final grams = _numbers(ocrText, [
      RegExp(r'(<\s*)?(\d+(?:[.,]\d+)?)\s*g\b', caseSensitive: false),
      RegExp(r'\bg\s+(<\s*)?(\d+(?:[.,]\d+)?)', caseSensitive: false),
    ]);
    final kcal = _numbers(ocrText, [
      RegExp(r'()(\d+(?:[.,]\d+)?)\s*kcal', caseSensitive: false),
      RegExp(r'kcal\s+()(\d+(?:[.,]\d+)?)', caseSensitive: false),
      RegExp(
        r'kj\s*/\s*kcal\D{0,12}\d+(?:[.,]\d+)?\s*/\s*()(\d+(?:[.,]\d+)?)',
        caseSensitive: false,
      ),
    ]);
    final mentionsFiber = RegExp(
      r'aststoff|fibre|fiber|vezels|fibra|vlakna',
      caseSensitive: false,
    ).hasMatch(ocrText);

    final kept = <NutritionLabelField, double>{};
    final upperBounds = <NutritionLabelField>{};
    for (final (key, field) in const [
      ('calories', NutritionLabelField.calories),
      ('protein', NutritionLabelField.protein),
      ('carbs', NutritionLabelField.carbs),
      ('fat', NutritionLabelField.fat),
      ('fiber', NutritionLabelField.fiber),
    ]) {
      final value = (values[key] as num?)?.toDouble();
      if (value == null || !value.isFinite || value < 0) continue;
      if (field == NutritionLabelField.fiber && !mentionsFiber) continue;
      final printed = field == NutritionLabelField.calories ? kcal : grams;
      final match = printed.where((p) => (p.value - value).abs() < 0.001);
      if (match.isEmpty) continue;
      kept[field] = value;
      if (match.every((p) => p.lessThan)) upperBounds.add(field);
    }
    if (kept.isEmpty) return null;

    final serving = (values['serving'] as num?)?.toDouble();
    final servingPrinted = serving != null &&
        _numbers(ocrText, [
          RegExp(r'()(\d+(?:[.,]\d+)?)\s*(?:g|ml)\b', caseSensitive: false),
        ]).any((p) => (p.value - serving).abs() < 0.001);
    return NutritionLabelResult(
      caloriesPer100g: kept[NutritionLabelField.calories] ?? 0,
      proteinPer100g: kept[NutritionLabelField.protein] ?? 0,
      carbsPer100g: kept[NutritionLabelField.carbs] ?? 0,
      fatPer100g: kept[NutritionLabelField.fat] ?? 0,
      fiberPer100g: kept[NutritionLabelField.fiber] ?? 0,
      nutritionUnit: '${values['basis']}'.trim().toLowerCase() == 'ml'
          ? NutritionUnit.milliliter
          : NutritionUnit.gram,
      servingSizeG: servingPrinted ? serving : null,
      presentFields: kept.keys.toSet(),
      upperBoundFields: upperBounds,
    );
  }

  /// Numbers captured by group 2 of each pattern; group 1 marks a `<`.
  static List<({double value, bool lessThan})> _numbers(
    String text,
    List<RegExp> patterns,
  ) =>
      [
        for (final pattern in patterns)
          for (final match in pattern.allMatches(text))
            if (double.tryParse(match.group(2)!.replaceAll(',', '.'))
                case final value?)
              (value: value, lessThan: (match.group(1) ?? '').isNotEmpty),
      ];
}
