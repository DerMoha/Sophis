import 'package:shared_preferences/shared_preferences.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';

class NutritionScanFeedbackService {
  static const _scanCountKey = 'nutrition_scan_feedback_count';
  static const _correctionPrefix = 'nutrition_scan_corrections_';

  const NutritionScanFeedbackService();

  Future<void> record({
    required NutritionLabelResult scanned,
    required NutritionLabelResult confirmed,
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
    for (final entry in values.entries) {
      if ((entry.value.$1 - entry.value.$2).abs() < 0.01) continue;
      final key = '$_correctionPrefix${entry.key}';
      await preferences.setInt(key, (preferences.getInt(key) ?? 0) + 1);
    }
  }

  Future<Map<String, int>> correctionCounts() async {
    final preferences = await SharedPreferences.getInstance();
    return {
      'scans': preferences.getInt(_scanCountKey) ?? 0,
      for (final nutrient in ['calories', 'protein', 'carbs', 'fat', 'fiber'])
        nutrient: preferences.getInt('$_correctionPrefix$nutrient') ?? 0,
    };
  }
}
