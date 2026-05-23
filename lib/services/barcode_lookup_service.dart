import 'dart:collection';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/serving_size.dart';
import 'package:sophis/services/database_service.dart';
import 'package:sophis/services/openfoodfacts_service.dart';
import 'package:sophis/services/brocade_service.dart';
import 'package:sophis/services/service_result.dart';

enum LookupSource { cache, offDe, offWorld, brocade, manual, gemini }

enum CacheStatus {
  found('found'),
  partial('partial'),
  notFound('notFound');

  const CacheStatus(this.value);
  final String value;

  static CacheStatus fromString(String value) => switch (value) {
        'found' => CacheStatus.found,
        'partial' => CacheStatus.partial,
        'notFound' => CacheStatus.notFound,
        _ => CacheStatus.found,
      };
}

class BarcodeLookupData {
  final FoodItem? item;
  final String barcode;
  final LookupSource source;
  final bool isUserCorrected;
  final String? partialName;
  final String? partialBrand;
  final ServiceErrorType? error;
  final bool isStale;

  const BarcodeLookupData({
    required this.item,
    required this.barcode,
    required this.source,
    this.isUserCorrected = false,
    this.partialName,
    this.partialBrand,
    this.error,
    this.isStale = false,
  });
}

class BarcodeLookupService {
  final DatabaseService _db;
  final OpenFoodFactsService _offService;
  final BrocadeService _brocadeService;

  static const _foundTtl = Duration(days: 30);
  static const _partialTtl = Duration(days: 14);
  static const _notFoundTtl = Duration(days: 7);

  static const _memoryCacheMaxSize = 200;
  final LinkedHashMap<String, BarcodeProduct> _memoryCache = LinkedHashMap();

  BarcodeLookupService({
    required DatabaseService db,
    required OpenFoodFactsService offService,
    required BrocadeService brocadeService,
  })  : _db = db,
        _offService = offService,
        _brocadeService = brocadeService;

  Future<ServiceResult<BarcodeLookupData>> lookup(String barcode) async {
    // 1. Check in-memory cache (instant)
    final memoryHit = _memoryCache[barcode];
    if (memoryHit != null) {
      final status = CacheStatus.fromString(memoryHit.cacheStatus);
      if (memoryHit.isUserCorrected) {
        return Success(BarcodeLookupData(
          item: status == CacheStatus.notFound
              ? null
              : _barcodeProductToFoodItem(memoryHit),
          barcode: barcode,
          source: LookupSource.cache,
          isUserCorrected: true,
        ),);
      }
      final age = DateTime.now().difference(memoryHit.cachedAt);
      if (status == CacheStatus.found) {
        final isStale = age > _foundTtl;
        return Success(BarcodeLookupData(
          item: _barcodeProductToFoodItem(memoryHit),
          barcode: barcode,
          source: LookupSource.cache,
          isStale: isStale,
        ),);
      }
      if (status == CacheStatus.partial) {
        final isStale = age > _partialTtl;
        return Success(BarcodeLookupData(
          item: null,
          barcode: barcode,
          source: LookupSource.cache,
          partialName: memoryHit.name.isNotEmpty ? memoryHit.name : null,
          partialBrand: memoryHit.brand,
          isStale: isStale,
        ),);
      }
      if (status == CacheStatus.notFound) {
        final isStale = age > _notFoundTtl;
        if (!isStale) {
          return Success(BarcodeLookupData(
            item: null,
            barcode: barcode,
            source: LookupSource.cache,
          ),);
        }
      }
    }

    // 2. Check SQLite cache
    final cached = await _db.getCachedBarcode(barcode);
    if (cached != null) {
      _putMemoryCache(barcode, cached);

      final status = CacheStatus.fromString(cached.cacheStatus);

      if (cached.isUserCorrected) {
        return Success(BarcodeLookupData(
          item: status == CacheStatus.notFound
              ? null
              : _barcodeProductToFoodItem(cached),
          barcode: barcode,
          source: LookupSource.cache,
          isUserCorrected: true,
        ),);
      }

      final age = DateTime.now().difference(cached.cachedAt);

      if (status == CacheStatus.found) {
        final isStale = age > _foundTtl;
        if (!isStale) {
          return Success(BarcodeLookupData(
            item: _barcodeProductToFoodItem(cached),
            barcode: barcode,
            source: LookupSource.cache,
          ),);
        }
        // Stale-but-valid: return immediately, refresh in background
        _refreshInBackground(barcode);
        return Success(BarcodeLookupData(
          item: _barcodeProductToFoodItem(cached),
          barcode: barcode,
          source: LookupSource.cache,
          isStale: true,
        ),);
      }

      if (status == CacheStatus.partial) {
        final isStale = age > _partialTtl;
        if (!isStale) {
          return Success(BarcodeLookupData(
            item: null,
            barcode: barcode,
            source: LookupSource.cache,
            partialName: cached.name.isNotEmpty ? cached.name : null,
            partialBrand: cached.brand,
          ),);
        }
      }

      if (status == CacheStatus.notFound) {
        final isStale = age > _notFoundTtl;
        if (!isStale) {
          return Success(BarcodeLookupData(
            item: null,
            barcode: barcode,
            source: LookupSource.cache,
          ),);
        }
      }
    }

    // 3. Network lookup chain
    return _networkLookup(barcode);
  }

  Future<ServiceResult<BarcodeLookupData>> _networkLookup(
    String barcode,
  ) async {
    bool hadNetworkError = false;

    // 3a. Try OFF-DE
    final deResult = await _offService.lookupBarcodeDe(barcode);
    switch (deResult) {
      case Success<FoodItem?>(value: final item):
        if (item != null) {
          await cacheResult(barcode, item, LookupSource.offDe);
          return Success(BarcodeLookupData(
            item: item,
            barcode: barcode,
            source: LookupSource.offDe,
          ),);
        }
      case Failure<FoodItem?>(errorType: final errorType):
        if (errorType == ServiceErrorType.network) {
          hadNetworkError = true;
        }
    }

    // Short-circuit: if OFF-DE had a network error, OFF-World likely will too
    if (hadNetworkError) {
      return _handleNetworkError(barcode);
    }

    // 3b. Try OFF-World
    final worldResult = await _offService.lookupBarcode(barcode);
    switch (worldResult) {
      case Success<FoodItem?>(value: final item):
        if (item != null) {
          await cacheResult(barcode, item, LookupSource.offWorld);
          return Success(BarcodeLookupData(
            item: item,
            barcode: barcode,
            source: LookupSource.offWorld,
          ),);
        }
      case Failure<FoodItem?>(errorType: final errorType):
        if (errorType == ServiceErrorType.network) {
          hadNetworkError = true;
        }
    }

    if (hadNetworkError) {
      return _handleNetworkError(barcode);
    }

    // 3c. Try Brocade (name/brand only)
    final brocadeResult = await _brocadeService.lookup(barcode);
    if (brocadeResult.isSuccess) {
      final brocadeProduct = brocadeResult.value;
      await _cachePartial(barcode, brocadeProduct);
      return Success(BarcodeLookupData(
        item: null,
        barcode: barcode,
        source: LookupSource.brocade,
        partialName: brocadeProduct.name,
        partialBrand: brocadeProduct.brand,
      ),);
    }
    if (brocadeResult
        case Failure<BrocadeProduct>(errorType: final errorType)) {
      if (errorType == ServiceErrorType.network) {
        hadNetworkError = true;
      }
    }

    // Nothing found anywhere
    if (hadNetworkError) {
      return _handleNetworkError(barcode);
    }

    await _cacheNotFound(barcode);
    return Success(BarcodeLookupData(
      item: null,
      barcode: barcode,
      source: LookupSource.manual,
    ),);
  }

  ServiceResult<BarcodeLookupData> _handleNetworkError(String barcode) {
    return Success(BarcodeLookupData(
      item: null,
      barcode: barcode,
      source: LookupSource.manual,
      error: ServiceErrorType.network,
    ),);
  }

  void _refreshInBackground(String barcode) {
    _networkLookup(barcode).then((_) {
      // Result is cached by _networkLookup; no further action needed
    }).catchError((_) {
      // Background refresh failures are acceptable
    });
  }

  /// Cache a full product lookup result to SQLite + memory
  Future<void> cacheResult(
    String barcode,
    FoodItem item,
    LookupSource source,
  ) async {
    final companion = BarcodeProductsCompanion(
      barcode: Value(barcode),
      name: Value(item.name),
      brand: Value(item.brand),
      category: Value(item.category),
      caloriesPer100g: Value(item.caloriesPer100g),
      proteinPer100g: Value(item.proteinPer100g),
      carbsPer100g: Value(item.carbsPer100g),
      fatPer100g: Value(item.fatPer100g),
      imageUrl: Value(item.imageUrl),
      servingsJson: Value(
        item.servings.isNotEmpty
            ? jsonEncode(item.servings.map((s) => s.toJson()).toList())
            : null,
      ),
      cacheStatus: const Value('found'),
      isUserCorrected: const Value(false),
      cachedAt: Value(DateTime.now()),
      source: Value(source.name),
    );
    await _db.upsertBarcodeCache(companion);
    _invalidateMemoryCache(barcode);
  }

  /// Cache a partial result (name/brand only, no nutrition)
  Future<void> _cachePartial(String barcode, BrocadeProduct product) async {
    final companion = BarcodeProductsCompanion(
      barcode: Value(barcode),
      name: Value(product.name),
      brand: Value(product.brand),
      category: const Value('food'),
      caloriesPer100g: const Value(0),
      proteinPer100g: const Value(0),
      carbsPer100g: const Value(0),
      fatPer100g: const Value(0),
      cacheStatus: const Value('partial'),
      isUserCorrected: const Value(false),
      cachedAt: Value(DateTime.now()),
      source: const Value('brocade'),
    );
    await _db.upsertBarcodeCache(companion);
    _invalidateMemoryCache(barcode);
  }

  /// Cache a not-found result
  Future<void> _cacheNotFound(String barcode) async {
    final companion = BarcodeProductsCompanion(
      barcode: Value(barcode),
      name: const Value(''),
      category: const Value('food'),
      caloriesPer100g: const Value(0),
      proteinPer100g: const Value(0),
      carbsPer100g: const Value(0),
      fatPer100g: const Value(0),
      cacheStatus: const Value('notFound'),
      isUserCorrected: const Value(false),
      cachedAt: Value(DateTime.now()),
      source: const Value('manual'),
    );
    await _db.upsertBarcodeCache(companion);
    _invalidateMemoryCache(barcode);
  }

  /// Save a user correction for a barcode product
  Future<void> saveUserCorrection(String barcode, FoodItem item) async {
    final companion = BarcodeProductsCompanion(
      barcode: Value(barcode),
      name: Value(item.name),
      brand: Value(item.brand),
      category: Value(item.category),
      caloriesPer100g: Value(item.caloriesPer100g),
      proteinPer100g: Value(item.proteinPer100g),
      carbsPer100g: Value(item.carbsPer100g),
      fatPer100g: Value(item.fatPer100g),
      imageUrl: Value(item.imageUrl),
      servingsJson: Value(
        item.servings.isNotEmpty
            ? jsonEncode(item.servings.map((s) => s.toJson()).toList())
            : null,
      ),
      cacheStatus: const Value('found'),
      isUserCorrected: const Value(true),
      cachedAt: Value(DateTime.now()),
      source: const Value('manual'),
    );
    await _db.upsertBarcodeCache(companion);
    _invalidateMemoryCache(barcode);
  }

  /// Remove user override and re-fetch from API
  Future<ServiceResult<BarcodeLookupData>> resetCorrection(
    String barcode,
  ) async {
    await _db.deleteBarcodeCache(barcode);
    _invalidateMemoryCache(barcode);
    return lookup(barcode);
  }

  /// Clean up expired cache entries
  Future<void> cleanExpiredCache() async {
    await _db.deleteExpiredBarcodeCache();
  }

  // ---------------------------------------------------------------------------
  // Memory cache management
  // ---------------------------------------------------------------------------

  void _putMemoryCache(String barcode, BarcodeProduct product) {
    _memoryCache[barcode] = product;
    if (_memoryCache.length > _memoryCacheMaxSize) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
  }

  void _invalidateMemoryCache(String barcode) {
    _memoryCache.remove(barcode);
  }

  FoodItem _barcodeProductToFoodItem(BarcodeProduct cached) {
    List<ServingSize> servings = [];
    if (cached.servingsJson != null) {
      try {
        final list = jsonDecode(cached.servingsJson!) as List;
        servings = list
            .map((s) => ServingSize.fromJson(s as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint(
          'Failed to parse cached servings JSON for ${cached.barcode}: $e',
        );
      }
    }

    return FoodItem(
      id: cached.barcode,
      name: cached.name,
      category: cached.category ?? 'food',
      caloriesPer100g: cached.caloriesPer100g,
      proteinPer100g: cached.proteinPer100g,
      carbsPer100g: cached.carbsPer100g,
      fatPer100g: cached.fatPer100g,
      barcode: cached.barcode,
      brand: cached.brand,
      imageUrl: cached.imageUrl,
      servings: servings,
    );
  }
}