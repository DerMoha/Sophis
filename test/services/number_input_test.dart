import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/utils/number_utils.dart';

void main() {
  group('Measurement input', () {
    test('accepted decimal commas and dots without changing the amount', () {
      expect(NumberUtils.parseInput(' 72,5 '), 72.5);
      expect(NumberUtils.parseInput('72.5'), 72.5);
      expect(NumberUtils.parseInput('0'), 0);
      expect(NumberUtils.parseInput(',5'), 0.5);
    });
    test('rejected malformed and non-finite values', () {
      for (final input in ['', 'NaN', 'Infinity', '1,2,3', '1.000,5', 'food']) {
        expect(NumberUtils.parseInput(input), isNull, reason: input);
      }
    });
  });
}
