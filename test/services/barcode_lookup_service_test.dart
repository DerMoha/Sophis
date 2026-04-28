import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sophis/models/food_item.dart';
import 'package:sophis/services/barcode_lookup_service.dart';
import 'package:sophis/services/brocade_service.dart';
import 'package:sophis/services/database_service.dart';
import 'package:sophis/services/openfoodfacts_service.dart';
import 'package:sophis/services/service_result.dart';

class MockDatabaseService extends Mock implements DatabaseService {}

class MockOpenFoodFactsService extends Mock implements OpenFoodFactsService {}

class MockBrocadeService extends Mock implements BrocadeService {}

class FakeBarcodeProductsCompanion extends Fake
    implements BarcodeProductsCompanion {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeBarcodeProductsCompanion());
  });

  late MockDatabaseService mockDb;
  late MockOpenFoodFactsService mockOff;
  late MockBrocadeService mockBrocade;
  late BarcodeLookupService service;

  setUp(() {
    mockDb = MockDatabaseService();
    mockOff = MockOpenFoodFactsService();
    mockBrocade = MockBrocadeService();
    service = BarcodeLookupService(
      db: mockDb,
      offService: mockOff,
      brocadeService: mockBrocade,
    );
  });

  group('BarcodeLookupService', () {
    const testBarcode = '4000521005108';

    const testFoodItem = FoodItem(
      id: testBarcode,
      name: 'Test Product',
      category: 'food',
      caloriesPer100g: 250,
      proteinPer100g: 10,
      carbsPer100g: 30,
      fatPer100g: 12,
      barcode: testBarcode,
    );

    test('returns cache hit immediately without querying APIs', () async {
      final cachedProduct = BarcodeProduct(
        barcode: testBarcode,
        name: 'Cached Product',
        brand: null,
        category: 'food',
        caloriesPer100g: 200,
        proteinPer100g: 8,
        carbsPer100g: 25,
        fatPer100g: 10,
        imageUrl: null,
        servingsJson: null,
        isUserCorrected: false,
        cachedAt: DateTime.now(),
        source: 'offDe',
      );

      when(() => mockDb.getCachedBarcode(testBarcode))
          .thenAnswer((_) async => cachedProduct);

      final result = await service.lookup(testBarcode);

      expect(result, isA<Success<BarcodeLookupData>>());
      final data = (result as Success<BarcodeLookupData>).value;
      expect(data.source, equals(LookupSource.cache));
      expect(data.item, isNotNull);
      expect(data.item!.name, equals('Cached Product'));

      verifyNever(() => mockOff.lookupBarcodeDe(any()));
      verifyNever(() => mockOff.lookupBarcode(any()));
      verifyNever(() => mockBrocade.lookup(any()));
    });

    test('falls back to OFF-DE when no cache', () async {
      when(() => mockDb.getCachedBarcode(testBarcode))
          .thenAnswer((_) async => null);
      when(() => mockOff.lookupBarcodeDe(testBarcode))
          .thenAnswer((_) async => testFoodItem);
      when(() => mockDb.upsertBarcodeCache(any())).thenAnswer((_) async {});

      final result = await service.lookup(testBarcode);

      expect(result, isA<Success<BarcodeLookupData>>());
      final data = (result as Success<BarcodeLookupData>).value;
      expect(data.source, equals(LookupSource.offDe));
      expect(data.item, isNotNull);
      verifyNever(() => mockOff.lookupBarcode(any()));
      verifyNever(() => mockBrocade.lookup(any()));
    });

    test('falls back to OFF-World when OFF-DE returns null', () async {
      when(() => mockDb.getCachedBarcode(testBarcode))
          .thenAnswer((_) async => null);
      when(() => mockOff.lookupBarcodeDe(testBarcode))
          .thenAnswer((_) async => null);
      when(() => mockOff.lookupBarcode(testBarcode))
          .thenAnswer((_) async => testFoodItem);
      when(() => mockDb.upsertBarcodeCache(any())).thenAnswer((_) async {});

      final result = await service.lookup(testBarcode);

      expect(result, isA<Success<BarcodeLookupData>>());
      final data = (result as Success<BarcodeLookupData>).value;
      expect(data.source, equals(LookupSource.offWorld));
      expect(data.item, isNotNull);
      verifyNever(() => mockBrocade.lookup(any()));
    });

    test('falls back to Brocade when both OFF endpoints fail', () async {
      when(() => mockDb.getCachedBarcode(testBarcode))
          .thenAnswer((_) async => null);
      when(() => mockOff.lookupBarcodeDe(testBarcode))
          .thenAnswer((_) async => null);
      when(() => mockOff.lookupBarcode(testBarcode))
          .thenAnswer((_) async => null);
      when(() => mockBrocade.lookup(testBarcode)).thenAnswer(
        (_) async => const Success(
          BrocadeProduct(name: 'Brocade Product', brand: 'TestBrand'),
        ),
      );

      final result = await service.lookup(testBarcode);

      expect(result, isA<Success<BarcodeLookupData>>());
      final data = (result as Success<BarcodeLookupData>).value;
      expect(data.source, equals(LookupSource.brocade));
      expect(data.item, isNull);
      expect(data.partialName, equals('Brocade Product'));
      expect(data.partialBrand, equals('TestBrand'));
    });

    test('returns manual source when all lookups fail', () async {
      when(() => mockDb.getCachedBarcode(testBarcode))
          .thenAnswer((_) async => null);
      when(() => mockOff.lookupBarcodeDe(testBarcode))
          .thenAnswer((_) async => null);
      when(() => mockOff.lookupBarcode(testBarcode))
          .thenAnswer((_) async => null);
      when(() => mockBrocade.lookup(testBarcode)).thenAnswer(
        (_) async => const Failure(ServiceErrorType.notFound, 'Not found'),
      );

      final result = await service.lookup(testBarcode);

      expect(result, isA<Success<BarcodeLookupData>>());
      final data = (result as Success<BarcodeLookupData>).value;
      expect(data.source, equals(LookupSource.manual));
      expect(data.item, isNull);
      expect(data.error, isNull);
    });

    test('propagates network error when Brocade fails with network', () async {
      when(() => mockDb.getCachedBarcode(testBarcode))
          .thenAnswer((_) async => null);
      when(() => mockOff.lookupBarcodeDe(testBarcode))
          .thenAnswer((_) async => null);
      when(() => mockOff.lookupBarcode(testBarcode))
          .thenAnswer((_) async => null);
      when(() => mockBrocade.lookup(testBarcode)).thenAnswer(
        (_) async => const Failure(ServiceErrorType.network, 'No connection'),
      );

      final result = await service.lookup(testBarcode);

      expect(result, isA<Success<BarcodeLookupData>>());
      final data = (result as Success<BarcodeLookupData>).value;
      expect(data.source, equals(LookupSource.manual));
      expect(data.error, equals(ServiceErrorType.network));
    });
  });
}
