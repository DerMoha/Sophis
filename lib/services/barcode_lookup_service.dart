import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../models/food_item.dart';
import '../models/serving_size.dart';
import 'database_service.dart';
import 'openfoodfacts_service.dart';
import 'brocade_service.dart';
import 'service_result.dart';

enum LookupSource { cache, offDe, offWorld, brocade, manual, gemini }

class BarcodeLookupResult {
  final FoodItem? item;
  final String barcode;
  final LookupSource source;
  final bool isUserCorrected;
  final String? partialName;
  final String? partialBrand;
  final ServiceErrorType? error;

  const BarcodeLookupResult({
    required this.item,
    required this.barcode,
    required this.source,
    this.isUserCorrected = false,
    this.partialName,
    this.partialBrand,
    this.error,
  });
}

class BarcodeLookupService {
  final DatabaseService _db;
  final OpenFoodFactsService _offService;
  final BrocadeService _brocadeService;

  static const _cacheMaxAge = Duration(days: 30);

  BarcodeLookupService({
    required DatabaseService db,
    required OpenFoodFactsService offService,
    required BrocadeService brocadeService,
  })  : _db = db,
        _offService = offService,
        _brocadeService = brocadeService;

  /// Run the full lookup chain for a barcode
  Future<BarcodeLookupResult> lookup(String barcode) async {
    // 1. Check local cache
    final cached = await _db.getCachedBarcode(barcode);
    if (cached != null) {
      if (cached.isUserCorrected) {
        return BarcodeLookupResult(
          item: _barcodeProductToFoodItem(cached),
          barcode: barcode,
          source: LookupSource.cache,
          isUserCorrected: true,
        );
      }
      // Check if cache is still valid
      final age = DateTime.now().difference(cached.cachedAt);
      if (age < _cacheMaxAge) {
        return BarcodeLookupResult(
          item: _barcodeProductToFoodItem(cached),
          barcode: barcode,
          source: LookupSource.cache,
        );
      }
    }

    // Track whether all failures were network-related
    bool allNetworkErrors = true;

    // 2. Try OpenFoodFacts DE
    var product = await _offService.lookupBarcodeDe(barcode);
    if (product != null) {
      await cacheResult(barcode, product, LookupSource.offDe);
      return BarcodeLookupResult(
        item: product,
        barcode: barcode,
        source: LookupSource.offDe,
      );
    }

    // 3. Try OpenFoodFacts World
    product = await _offService.lookupBarcode(barcode);
    if (product != null) {
      await cacheResult(barcode, product, LookupSource.offWorld);
      return BarcodeLookupResult(
        item: product,
        barcode: barcode,
        source: LookupSource.offWorld,
      );
    }

    // 4. Try Brocade (name/brand only)
    final brocadeResult = await _brocadeService.lookup(barcode);
    if (brocadeResult.isSuccess) {
      final brocadeProduct = brocadeResult.value;
      return BarcodeLookupResult(
        item: null,
        barcode: barcode,
        source: LookupSource.brocade,
        partialName: brocadeProduct.name,
        partialBrand: brocadeProduct.brand,
      );
    }
    if (brocadeResult case Failure<BrocadeProduct>(errorType: final errorType)) {
      if (errorType != ServiceErrorType.network) {
        allNetworkErrors = false;
      }
    }

    // 5. Nothing found — indicate network error if that was the cause
    return BarcodeLookupResult(
      item: null,
      barcode: barcode,
      source: LookupSource.manual,
      error: allNetworkErrors ? ServiceErrorType.network : null,
    );
  }

  /// Cache a lookup result to SQLite
  Future<void> cacheResult(
    String barcode,
    FoodItem item,
    LookupSource source,
  ) async {
    await _db.upsertBarcodeCache(
      BarcodeProductsCompanion(
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
        isUserCorrected: const Value(false),
        cachedAt: Value(DateTime.now()),
        source: Value(source.name),
      ),
    );
  }

  /// Save a user correction for a barcode product
  Future<void> saveUserCorrection(String barcode, FoodItem item) async {
    await _db.upsertBarcodeCache(
      BarcodeProductsCompanion(
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
        isUserCorrected: const Value(true),
        cachedAt: Value(DateTime.now()),
        source: const Value('manual'),
      ),
    );
  }

  /// Remove user override and re-fetch from API
  Future<BarcodeLookupResult> resetCorrection(String barcode) async {
    await _db.deleteBarcodeCache(barcode);
    return lookup(barcode);
  }

  /// Clean up expired cache entries
  Future<void> cleanExpiredCache() async {
    await _db.deleteExpiredBarcodeCache();
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
        debugPrint('Failed to parse cached servings JSON for ${cached.barcode}: $e');
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
