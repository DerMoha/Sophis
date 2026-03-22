import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sophis/services/gemini_food_service.dart';

void main() {
  group('Gemini rate limiting', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('canMakeRequest returns true when count is below limit', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await GeminiFoodService.canMakeRequest(), isTrue);
    });

    test('canMakeRequest returns true at count 19', () async {
      final now = DateTime.now();
      final today = '${now.year}-${now.month}-${now.day}';
      SharedPreferences.setMockInitialValues({
        'gemini_request_date': today,
        'gemini_request_count': 19,
      });
      expect(await GeminiFoodService.canMakeRequest(), isTrue);
    });

    test('canMakeRequest returns false when count reaches limit', () async {
      final now = DateTime.now();
      final today = '${now.year}-${now.month}-${now.day}';
      SharedPreferences.setMockInitialValues({
        'gemini_request_date': today,
        'gemini_request_count': 20,
      });
      expect(await GeminiFoodService.canMakeRequest(), isFalse);
    });

    test('canMakeRequest returns false when count exceeds limit', () async {
      final now = DateTime.now();
      final today = '${now.year}-${now.month}-${now.day}';
      SharedPreferences.setMockInitialValues({
        'gemini_request_date': today,
        'gemini_request_count': 25,
      });
      expect(await GeminiFoodService.canMakeRequest(), isFalse);
    });

    test('counter resets on new day', () async {
      SharedPreferences.setMockInitialValues({
        'gemini_request_date': '2020-1-1',
        'gemini_request_count': 20,
      });
      expect(await GeminiFoodService.canMakeRequest(), isTrue);
      expect(await GeminiFoodService.getRequestsToday(), equals(0));
    });

    test('getRemainingRequests returns correct value', () async {
      final now = DateTime.now();
      final today = '${now.year}-${now.month}-${now.day}';
      SharedPreferences.setMockInitialValues({
        'gemini_request_date': today,
        'gemini_request_count': 15,
      });
      expect(await GeminiFoodService.getRemainingRequests(), equals(5));
    });

    test('getRemainingRequests clamps to zero', () async {
      final now = DateTime.now();
      final today = '${now.year}-${now.month}-${now.day}';
      SharedPreferences.setMockInitialValues({
        'gemini_request_date': today,
        'gemini_request_count': 25,
      });
      expect(await GeminiFoodService.getRemainingRequests(), equals(0));
    });

    test('dailyLimit is 20', () {
      expect(GeminiFoodService.dailyLimit, equals(20));
    });
  });
}
