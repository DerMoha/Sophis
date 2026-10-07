import 'package:shared_preferences/shared_preferences.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';

enum NutritionScanOutcome {
  localSuccess,
  cloudSuccess,
  partialManualCompletion,
  rescan,
  fieldCorrection,
}

class NutritionScanFeedbackService {
  static const _scanCountKey = 'nutrition_scan_feedback_count';
  static const _correctionPrefix = 'nutrition_scan_corrections_';
  static const _outcomePrefix = 'nutrition_scan_outcome_';

  const NutritionScanFeedbackService();

  Future<void> record({
    required NutritionLabelResult scanned,
    required NutritionLabelResult confirmed,
    NutritionScanOutcome? outcome,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(
      _scanCountKey,
      (preferences.getInt(_scanCountKey) ?? 0) + 1,
    );
    final values = <String, (double, double)>{
      'calories': (scanned.caloriesPer100g, confirmed.caloriesPer100g),
      'protein': (scanned.proteinPer100g, confirmed.proteinPer100g),
      'carbs': (scanned.carbsPer100g, confirmed.carbsPer100g),
      'fat': (scanned.fatPer100g, confirmed.fatPer100g),
      'fiber': (scanned.fiberPer100g, confirmed.fiberPer100g),
    };
    var fieldWasCorrected = false;
    for (final entry in values.entries) {
      if ((entry.value.$1 - entry.value.$2).abs() < 0.01) continue;
      fieldWasCorrected = true;
      final key = '$_correctionPrefix${entry.key}';
      await preferences.setInt(key, (preferences.getInt(key) ?? 0) + 1);
    }
    if (outcome != null) await _incrementOutcome(preferences, outcome);
    if (fieldWasCorrected) {
      await _incrementOutcome(
        preferences,
        NutritionScanOutcome.fieldCorrection,
      );
    }
  }

  Future<void> recordOutcome(NutritionScanOutcome outcome) async {
    final preferences = await SharedPreferences.getInstance();
    await _incrementOutcome(preferences, outcome);
  }

  Future<Map<String, int>> correctionCounts() async {
    final preferences = await SharedPreferences.getInstance();
    return {
      'scans': preferences.getInt(_scanCountKey) ?? 0,
      for (final nutrient in ['calories', 'protein', 'carbs', 'fat', 'fiber'])
        nutrient: preferences.getInt('$_correctionPrefix$nutrient') ?? 0,
    };
  }

  Future<Map<String, int>> outcomeCounts() async {
    final preferences = await SharedPreferences.getInstance();
    return {
      for (final outcome in NutritionScanOutcome.values)
        outcome.name: preferences.getInt('$_outcomePrefix${outcome.name}') ?? 0,
    };
  }

  Future<void> _incrementOutcome(
    SharedPreferences preferences,
    NutritionScanOutcome outcome,
  ) async {
    final key = '$_outcomePrefix${outcome.name}';
    await preferences.setInt(key, (preferences.getInt(key) ?? 0) + 1);
  }
}
