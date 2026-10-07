import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/social/partner_consent.dart';

void main() {
  final date = DateTime(2026, 10, 7);
  DateTime time(int hour) => date.add(Duration(hours: hour));
  PartnerSourceEntry source(int hour) => PartnerSourceEntry(
        originallyLoggedAt: time(hour),
        entry: FoodEntry(
          id: '$hour',
          name: 'Meal',
          calories: 100,
          protein: 10,
          carbs: 10,
          fat: 2,
          timestamp: date,
          meal: 'dinner',
        ),
      );
  PartnerConsent consent(
    List<SharingPeriod> periods, {
    bool disconnected = false,
  }) =>
      PartnerConsent(
        connectionId: 'connection1',
        shareMeals: true,
        shareDailySummary: true,
        sharePhotos: false,
        periods: periods,
        disconnected: disconnected,
      );
  group('PartnerConsent', () {
    test('excluded activation-day history and paused entries after resume', () {
      final active = consent([
        SharingPeriod(start: time(10), end: time(12)),
        SharingPeriod(start: time(15)),
      ]);
      expect(active.shouldSendMeal(source(9)), isFalse);
      expect(active.shouldSendMeal(source(10)), isTrue);
      expect(active.shouldSendMeal(source(12)), isFalse);
      expect(active.shouldSendMeal(source(14)), isFalse);
      expect(active.shouldSendMeal(source(15)), isTrue);
      expect(
        active.summaryForDate(
          [source(9), source(10), source(12), source(15)],
          date,
        )?.calories,
        200,
      );
    });
    test('froze paused summaries while allowing privacy removal', () {
      final paused = consent([SharingPeriod(start: time(10), end: time(12))]);
      expect(paused.shouldSendMeal(source(11)), isFalse);
      expect(paused.summaryForDate([source(11)], date), isNull);
      expect(paused.shouldSendPrivacyRemoval, isTrue);
    });
    test('revoked disconnected access and kept connection settings independent',
        () {
      final active = consent([SharingPeriod(start: time(10))]);
      final disconnected =
          consent([SharingPeriod(start: time(10))], disconnected: true);
      expect(active.shouldSendMeal(source(11)), isTrue);
      expect(disconnected.shouldSendMeal(source(11)), isFalse);
      expect(disconnected.shouldSendPrivacyRemoval, isTrue);
    });
    test('rejected overlapping consent windows', () {
      expect(
        () => consent(
          [SharingPeriod(start: time(10)), SharingPeriod(start: time(15))],
        ),
        throwsArgumentError,
      );
    });
  });
}
