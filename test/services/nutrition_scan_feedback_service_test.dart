import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/nutrition_scan_feedback_service.dart';

void main() {
  test('stores only aggregate correction counts', () async {
    SharedPreferences.setMockInitialValues({});
    const service = NutritionScanFeedbackService();
    const scanned = NutritionLabelResult(
      caloriesPer100g: 200,
      proteinPer100g: 10,
      carbsPer100g: 20,
      fatPer100g: 5,
    );
    await service.record(
      scanned: scanned,
      confirmed: scanned.copyWith(caloriesPer100g: 250, fatPer100g: 8),
    );

    final counts = await service.correctionCounts();
    expect(counts['scans'], 1);
    expect(counts['calories'], 1);
    expect(counts['fat'], 1);
    expect(counts['protein'], 0);
  });
}
