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

  BarcodeProduct makeCachedProduct({
    String barcode = testBarcode,
    String name = 'Cached Product',
    String? brand,
    String cacheStatus = 'found',
    bool isUserCorrected = false,
    int daysAgo = 0,
  }) {
    return BarcodeProduct(
      barcode: barcode,
      name: name,
      brand: brand,
      category: 'food',
      caloriesPer100g: 200,
      proteinPer100g: 8,
      carbsPer100g: 25,
      fatPer100g: 10,
      imageUrl: null,
      servingsJson: null,
      cacheStatus: cacheStatus,
      isUserCorrected: isUserCorrected,
      cachedAt: DateTime.now().subtract(Duration(days: daysAgo)),
      source: 'offDe',
    );
  }

  setUp(() {
    mockDb = MockDatabaseService();
    mockOff = MockOpenFoodFactsService();
    mockBrocade = MockBrocadeService();
    service = BarcodeLookupService(
      db: mockDb,
      offService: mockOff,
      brocadeService: mockBrocade,
    );

    // Default: no cache hit
    when(() => mockDb.getCachedBarcode(testBarcode))
        .thenAnswer((_) async => null);
    // Default: no result from OFF-DE
    when(() => mockOff.lookupBarcodeDe(testBarcode))
        .thenAnswer((_) async => const Success(null));
    // Default: no result from OFF-World
    when(() => mockOff.lookupBarcode(testBarcode))
        .thenAnswer((_) async => const Success(null));
    // Default: no result from Brocade
    when(() => mockBrocade.lookup(testBarcode))
        .thenAnswer((_) async => const Failure(ServiceErrorType.notFound, 'Not found'));
    // Default: upsert succeeds
    when(() => mockDb.upsertBarcodeCache(any())).thenAnswer((_) async {});
  });

  group('BarcodeLookupService', () {
    group('cache hits', () {
      test('returns fresh found cache hit immediately without querying APIs',
          () async {
        final cachedProduct = makeCachedProduct(cacheStatus: 'found');
        when(() => mockDb.getCachedBarcode(testBarcode))
            .thenAnswer((_) async => cachedProduct);

        final result = await service.lookup(testBarcode);

        expect(result, isA<Success<BarcodeLookupData>>());
        final data = (result as Success<BarcodeLookupData>).value;
        expect(data.source, equals(LookupSource.cache));
        expect(data.item, isNotNull);
        expect(data.item!.name, equals('Cached Product'));
        expect(data.isStale, isFalse);

        verifyNever(() => mockOff.lookupBarcodeDe(any()));
        verifyNever(() => mockOff.lookupBarcode(any()));
        verifyNever(() => mockBrocade.lookup(any()));
      });

      test('returns stale found cache hit with isStale=true and triggers background refresh',
          () async {
        final cachedProduct =
            makeCachedProduct(cacheStatus: 'found', daysAgo: 31);
        when(() => mockDb.getCachedBarcode(testBarcode))
            .thenAnswer((_) async => cachedProduct);
        // Background refresh would call OFF-DE
        when(() => mockOff.lookupBarcodeDe(testBarcode))
            .thenAnswer((_) async => const Success(testFoodItem));

        final result = await service.lookup(testBarcode);

        expect(result, isA<Success<BarcodeLookupData>>());
        final data = (result as Success<BarcodeLookupData>).value;
        expect(data.source, equals(LookupSource.cache));
        expect(data.item, isNotNull);
        expect(data.isStale, isTrue);
      });

      test('returns user-corrected cache immediately regardless of age',
          () async {
        final cachedProduct = makeCachedProduct(
          cacheStatus: 'found',
          isUserCorrected: true,
          daysAgo: 60,
        );
        when(() => mockDb.getCachedBarcode(testBarcode))
            .thenAnswer((_) async => cachedProduct);

        final result = await service.lookup(testBarcode);

        expect(result, isA<Success<BarcodeLookupData>>());
        final data = (result as Success<BarcodeLookupData>).value;
        expect(data.source, equals(LookupSource.cache));
        expect(data.item, isNotNull);
        expect(data.isUserCorrected, isTrue);

        verifyNever(() => mockOff.lookupBarcodeDe(any()));
      });

      test('returns partial cache hit with name/brand', () async {
        final cachedProduct = makeCachedProduct(
          cacheStatus: 'partial',
          name: 'Partial Product',
          brand: 'PartialBrand',
        );
        when(() => mockDb.getCachedBarcode(testBarcode))
            .thenAnswer((_) async => cachedProduct);

        final result = await service.lookup(testBarcode);

        expect(result, isA<Success<BarcodeLookupData>>());
        final data = (result as Success<BarcodeLookupData>).value;
        expect(data.source, equals(LookupSource.cache));
        expect(data.item, isNull);
        expect(data.partialName, equals('Partial Product'));
        expect(data.partialBrand, equals('PartialBrand'));
      });

      test('returns not-found cache hit immediately', () async {
        final cachedProduct = makeCachedProduct(
          cacheStatus: 'notFound',
          name: '',
        );
        when(() => mockDb.getCachedBarcode(testBarcode))
            .thenAnswer((_) async => cachedProduct);

        final result = await service.lookup(testBarcode);

        expect(result, isA<Success<BarcodeLookupData>>());
        final data = (result as Success<BarcodeLookupData>).value;
        expect(data.source, equals(LookupSource.cache));
        expect(data.item, isNull);

        verifyNever(() => mockOff.lookupBarcodeDe(any()));
        verifyNever(() => mockOff.lookupBarcode(any()));
        verifyNever(() => mockBrocade.lookup(any()));
      });

      test('expired not-found cache triggers network lookup', () async {
        final cachedProduct = makeCachedProduct(
          cacheStatus: 'notFound',
          name: '',
          daysAgo: 8,
        );
        when(() => mockDb.getCachedBarcode(testBarcode))
            .thenAnswer((_) async => cachedProduct);
        when(() => mockOff.lookupBarcodeDe(testBarcode))
            .thenAnswer((_) async => const Success(testFoodItem));

        final result = await service.lookup(testBarcode);

        expect(result, isA<Success<BarcodeLookupData>>());
        final data = (result as Success<BarcodeLookupData>).value;
        expect(data.source, equals(LookupSource.offDe));
        expect(data.item, isNotNull);
      });

      test('memory cache provides instant hit on second lookup', () async {
        final cachedProduct = makeCachedProduct(cacheStatus: 'found');
        when(() => mockDb.getCachedBarcode(testBarcode))
            .thenAnswer((_) async => cachedProduct);

        // First lookup hits SQLite
        final result1 = await service.lookup(testBarcode);
        expect(result1, isA<Success<BarcodeLookupData>>());

        // Second lookup should use memory cache (no additional DB calls)
        final result2 = await service.lookup(testBarcode);
        expect(result2, isA<Success<BarcodeLookupData>>());
        final data2 = (result2 as Success<BarcodeLookupData>).value;
        expect(data2.source, equals(LookupSource.cache));
        expect(data2.item, isNotNull);

        // DB only called once (memory cache served the second)
        verify(() => mockDb.getCachedBarcode(testBarcode)).called(1);
      });
    });

    group('network fallback', () {
      test('falls back to OFF-DE when no cache', () async {
        when(() => mockOff.lookupBarcodeDe(testBarcode))
            .thenAnswer((_) async => const Success(testFoodItem));

        final result = await service.lookup(testBarcode);

        expect(result, isA<Success<BarcodeLookupData>>());
        final data = (result as Success<BarcodeLookupData>).value;
        expect(data.source, equals(LookupSource.offDe));
        expect(data.item, isNotNull);
        verifyNever(() => mockOff.lookupBarcode(any()));
        verifyNever(() => mockBrocade.lookup(any()));
      });

      test('falls back to OFF-World when OFF-DE returns null', () async {
        when(() => mockOff.lookupBarcodeDe(testBarcode))
            .thenAnswer((_) async => const Success(null));
        when(() => mockOff.lookupBarcode(testBarcode))
            .thenAnswer((_) async => const Success(testFoodItem));

        final result = await service.lookup(testBarcode);

        expect(result, isA<Success<BarcodeLookupData>>());
        final data = (result as Success<BarcodeLookupData>).value;
        expect(data.source, equals(LookupSource.offWorld));
        expect(data.item, isNotNull);
      });

      test('falls back to Brocade when both OFF endpoints return null',
          () async {
        when(() => mockOff.lookupBarcodeDe(testBarcode))
            .thenAnswer((_) async => const Success(null));
        when(() => mockOff.lookupBarcode(testBarcode))
            .thenAnswer((_) async => const Success(null));
        when(() => mockBrocade.lookup(testBarcode)).thenAnswer(
          (_) async =>
              const Success(BrocadeProduct(name: 'Brocade Product', brand: 'TestBrand')),
        );

        final result = await service.lookup(testBarcode);

        expect(result, isA<Success<BarcodeLookupData>>());
        final data = (result as Success<BarcodeLookupData>).value;
        expect(data.source, equals(LookupSource.brocade));
        expect(data.item, isNull);
        expect(data.partialName, equals('Brocade Product'));
        expect(data.partialBrand, equals('TestBrand'));
      });

      test('caches not-found result when all lookups fail', () async {
        when(() => mockOff.lookupBarcodeDe(testBarcode))
            .thenAnswer((_) async => const Success(null));
        when(() => mockOff.lookupBarcode(testBarcode))
            .thenAnswer((_) async => const Success(null));
        when(() => mockBrocade.lookup(testBarcode)).thenAnswer(
          (_) async =>
              const Failure(ServiceErrorType.notFound, 'Not found'),
        );

        final result = await service.lookup(testBarcode);

        expect(result, isA<Success<BarcodeLookupData>>());
        final data = (result as Success<BarcodeLookupData>).value;
        expect(data.source, equals(LookupSource.manual));
        expect(data.item, isNull);
        expect(data.error, isNull);

        // Should have cached the not-found result
        verify(() => mockDb.upsertBarcodeCache(any())).called(1);
      });

      test('short-circuits on OFF-DE network error without calling OFF-World',
          () async {
        when(() => mockOff.lookupBarcodeDe(testBarcode)).thenAnswer(
          (_) async => const Failure(ServiceErrorType.network, 'No connection'),
        );

        final result = await service.lookup(testBarcode);

        expect(result, isA<Success<BarcodeLookupData>>());
        final data = (result as Success<BarcodeLookupData>).value;
        expect(data.error, equals(ServiceErrorType.network));

        // OFF-World should NOT be called if OFF-DE had a network error
        verifyNever(() => mockOff.lookupBarcode(any()));
      });

      test('returns network error when OFF-DE fails with network error',
          () async {
        when(() => mockOff.lookupBarcodeDe(testBarcode)).thenAnswer(
          (_) async => const Failure(ServiceErrorType.network, 'No connection'),
        );

        final result = await service.lookup(testBarcode);

        expect(result, isA<Success<BarcodeLookupData>>());
        final data = (result as Success<BarcodeLookupData>).value;
        expect(data.error, equals(ServiceErrorType.network));
        expect(data.item, isNull);
      });

      test('continues to OFF-World when OFF-DE returns not-found', () async {
        when(() => mockOff.lookupBarcodeDe(testBarcode))
            .thenAnswer((_) async => const Success(null));
        when(() => mockOff.lookupBarcode(testBarcode))
            .thenAnswer((_) async => const Success(testFoodItem));

        final result = await service.lookup(testBarcode);

        expect(result, isA<Success<BarcodeLookupData>>());
        final data = (result as Success<BarcodeLookupData>).value;
        expect(data.source, equals(LookupSource.offWorld));
        expect(data.item, isNotNull);
      });
    });

    group('caching', () {
      test('cacheResult stores found status', () async {
        await service.cacheResult(testBarcode, testFoodItem, LookupSource.offDe);

        final captured =
            verify(() => mockDb.upsertBarcodeCache(captureAny())).captured;
        final companion = captured.first as BarcodeProductsCompanion;
        expect(companion.cacheStatus.value, equals('found'));
        expect(companion.isUserCorrected.value, equals(false));
      });

      test('saveUserCorrection stores found status with isUserCorrected=true',
          () async {
        await service.saveUserCorrection(testBarcode, testFoodItem);

        final captured =
            verify(() => mockDb.upsertBarcodeCache(captureAny())).captured;
        final companion = captured.first as BarcodeProductsCompanion;
        expect(companion.cacheStatus.value, equals('found'));
        expect(companion.isUserCorrected.value, equals(true));
      });

      test('resetCorrection deletes cache and re-looks up', () async {
        when(() => mockDb.deleteBarcodeCache(testBarcode))
            .thenAnswer((_) async {});
        when(() => mockDb.getCachedBarcode(testBarcode))
            .thenAnswer((_) async => null);
        when(() => mockOff.lookupBarcodeDe(testBarcode))
            .thenAnswer((_) async => const Success(testFoodItem));

        final result = await service.resetCorrection(testBarcode);

        expect(result, isA<Success<BarcodeLookupData>>());
        verify(() => mockDb.deleteBarcodeCache(testBarcode)).called(1);
      });

      test('cleanExpiredCache delegates to database', () async {
        when(() => mockDb.deleteExpiredBarcodeCache()).thenAnswer((_) async {});

        await service.cleanExpiredCache();

        verify(() => mockDb.deleteExpiredBarcodeCache()).called(1);
      });
    });

    group('negative caching', () {
      test('second lookup of unknown barcode uses cache', () async {
        // First lookup: not found, caches the result
        when(() => mockOff.lookupBarcodeDe(testBarcode))
            .thenAnswer((_) async => const Success(null));
        when(() => mockOff.lookupBarcode(testBarcode))
            .thenAnswer((_) async => const Success(null));
        when(() => mockBrocade.lookup(testBarcode)).thenAnswer(
          (_) async =>
              const Failure(ServiceErrorType.notFound, 'Not found'),
        );

        final result1 = await service.lookup(testBarcode);
        expect(result1, isA<Success<BarcodeLookupData>>());
        expect((result1 as Success<BarcodeLookupData>).value.item, isNull);

        // Simulate the not-found cache being populated in DB
        final notFoundCache = makeCachedProduct(
          cacheStatus: 'notFound',
          name: '',
        );
        when(() => mockDb.getCachedBarcode(testBarcode))
            .thenAnswer((_) async => notFoundCache);

        // Second lookup should use cache
        final result2 = await service.lookup(testBarcode);
        expect(result2, isA<Success<BarcodeLookupData>>());
        final data2 = (result2 as Success<BarcodeLookupData>).value;
        expect(data2.source, equals(LookupSource.cache));
        expect(data2.item, isNull);
      });
    });

    group('partial caching', () {
      test('stores partial result from Brocade with cacheStatus=partial',
          () async {
        when(() => mockOff.lookupBarcodeDe(testBarcode))
            .thenAnswer((_) async => const Success(null));
        when(() => mockOff.lookupBarcode(testBarcode))
            .thenAnswer((_) async => const Success(null));
        when(() => mockBrocade.lookup(testBarcode)).thenAnswer(
          (_) async => const Success(
            BrocadeProduct(name: 'Partial Product', brand: 'TestBrand'),
          ),
        );

        final result = await service.lookup(testBarcode);

        expect(result, isA<Success<BarcodeLookupData>>());
        final data = (result as Success<BarcodeLookupData>).value;
        expect(data.partialName, equals('Partial Product'));
        expect(data.partialBrand, equals('TestBrand'));

        // Verify partial cache was stored
        final captured =
            verify(() => mockDb.upsertBarcodeCache(captureAny())).captured;
        final companion = captured.first as BarcodeProductsCompanion;
        expect(companion.cacheStatus.value, equals('partial'));
      });
    });
  });
}