import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/partner_day.dart';
import 'package:sophis/services/partner/partner_backend.dart';

void main() {
  final entry = FoodEntry(
    id: 'rice',
    name: 'Rice',
    calories: 400,
    protein: 8,
    carbs: 88,
    fat: 2,
    fiber: 3,
    timestamp: DateTime(2026, 10, 25, 12),
    meal: 'lunch',
    sourceFoodId: 'private-library-id',
  );

  group('PartnerDay', () {
    test('computed remaining calories like the own dashboard', () {
      final day = PartnerDay(
        date: '2026-10-25',
        goals: NutritionGoals(calories: 2000),
        burned: 300,
        entries: [entry, entry],
      );

      expect(day.totals.calories, 800);
      expect(day.totals.protein, 16);
      expect(day.remainingCalories, 1500);
    });

    test('had no remaining calories without a goal', () {
      final day = PartnerDay(
        date: '2026-10-25',
        goals: null,
        burned: 0,
        entries: [entry],
      );

      expect(day.remainingCalories, isNull);
    });

    test('kept local library links private and round-tripped entries', () {
      final day = PartnerDay(
        date: '2026-10-25',
        goals: NutritionGoals(calories: 1800, protein: 120),
        burned: 0,
        entries: [entry],
      );
      final json = day.toJson();
      final entries = json['entries'] as List;

      expect((entries.single as Map).containsKey('sourceFoodId'), isFalse);

      final decoded = PartnerDay.fromJson(json);
      expect(decoded.date, '2026-10-25');
      expect(decoded.goals!.protein, 120);
      expect(decoded.entries.single.name, 'Rice');
      expect(decoded.entries.single.meal, 'lunch');
      expect(decoded.entries.single.sourceFoodId, isNull);
    });
  });

  group('PartnerInvite', () {
    test('normalized typed codes and rejected look-alike characters', () {
      expect(PartnerInvite.normalize(' abcd-2345 '), 'ABCD2345');
      expect(PartnerInvite.normalize('ABCD234O'), isNull);
      expect(PartnerInvite.normalize('ABC'), isNull);
    });

    test('built a partner deep link', () {
      final invite = PartnerInvite(
        code: 'ABCD2345',
        expiresAt: DateTime(2026),
      );

      expect(invite.link.toString(), 'sophis://partner?code=ABCD2345');
    });
  });
}
