import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/services/openfoodfacts_service.dart';
import 'package:sophis/services/service_result.dart';

void main() {
  group('OpenFoodFactsService', () {
    late OpenFoodFactsService service;

    setUp(() {
      service = OpenFoodFactsService();
    });

    test('search with empty query returns empty success', () async {
      final result = await service.search('');
      expect(result.isSuccess, isTrue);
      expect(result.value, isEmpty);
    });

    group('ServiceResult type', () {
      test('Success holds value', () {
        const result = Success<int>(42);
        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);
        expect(result.value, equals(42));
        expect(result.valueOrNull, equals(42));
      });

      test('Failure holds error type and message', () {
        const result =
            Failure<int>(ServiceErrorType.network, 'No connection');
        expect(result.isSuccess, isFalse);
        expect(result.isFailure, isTrue);
        expect(result.errorType, equals(ServiceErrorType.network));
        expect(result.message, equals('No connection'));
        expect(result.valueOrNull, isNull);
      });

      test('Failure.value throws', () {
        const result =
            Failure<int>(ServiceErrorType.notFound, 'Not found');
        expect(() => result.value, throwsA(isA<Exception>()));
      });
    });
  });
}
