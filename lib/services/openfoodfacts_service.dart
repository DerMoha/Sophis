import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import '../models/serving_size.dart';

/// Service for searching food products via OpenFoodFacts API
class OpenFoodFactsService {
  static const _baseUrl = 'https://world.openfoodfacts.org';
  static const _cacheDuration = Duration(minutes: 10);

  // In-memory cache: query -> (results, timestamp)
  final Map<String, _CacheEntry> _searchCache = {};

  /// Search for food products by name
  Future<List<FoodItem>> search(String query) async {
    if (query.isEmpty) return [];

    final normalizedQuery = query.toLowerCase().trim();

    // Check cache first
    final cached = _searchCache[normalizedQuery];
    if (cached != null && !cached.isExpired) {
      return cached.results;
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/cgi/search.pl?search_terms=$query&search_simple=1&action=process&json=1&page_size=20',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final products = data['products'] as List? ?? [];

      final results = products
          .map((p) => _parseProduct(p))
          .where((item) => item != null)
          .cast<FoodItem>()
          .toList();

      // Store in cache
      _searchCache[normalizedQuery] = _CacheEntry(results, DateTime.now());

      // Clean old cache entries (keep max 50)
      _cleanCache();

      return results;
    } catch (e) {
      return [];
    }
  }

  void _cleanCache() {
    if (_searchCache.length > 50) {
      // Remove expired entries first
      _searchCache.removeWhere((_, entry) => entry.isExpired);

      // If still too many, remove oldest
      if (_searchCache.length > 50) {
        final sortedKeys = _searchCache.keys.toList()
          ..sort((a, b) => _searchCache[a]!.timestamp
              .compareTo(_searchCache[b]!.timestamp));
        for (final key in sortedKeys.take(_searchCache.length - 50)) {
          _searchCache.remove(key);
        }
      }
    }
  }

  /// Lookup a product by barcode
  Future<FoodItem?> lookupBarcode(String barcode) async {
    try {
      final url = Uri.parse('$_baseUrl/api/v0/product/$barcode.json');
      final response = await http.get(url);
      
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data['status'] != 1) return null;

      return _parseProduct(data['product']);
    } catch (e) {
      return null;
    }
  }

  FoodItem? _parseProduct(Map<String, dynamic>? product) {
    if (product == null) return null;

    final name = product['product_name'] ?? product['product_name_en'];
    if (name == null || name.toString().isEmpty) return null;

    final nutrients = product['nutriments'] as Map<String, dynamic>? ?? {};

    // Get values per 100g
    final calories = _parseNutrient(nutrients, 'energy-kcal_100g') ??
        _parseNutrient(nutrients, 'energy-kcal') ??
        (_parseNutrient(nutrients, 'energy_100g') ?? 0) / 4.184;

    final protein = _parseNutrient(nutrients, 'proteins_100g') ?? 0;
    final carbs = _parseNutrient(nutrients, 'carbohydrates_100g') ?? 0;
    final fat = _parseNutrient(nutrients, 'fat_100g') ?? 0;

    // Extract brand
    final brand = product['brands']?.toString();

    // Extract image URL
    final imageUrl = product['image_front_small_url']?.toString() ??
        product['image_front_url']?.toString();

    // Extract serving size info
    final servingSize = product['serving_size']?.toString();
    final servingQuantity = _parseNutrient(
        {'q': product['serving_quantity']}, 'q');

    // Generate serving options
    List<ServingSize> servings = [];
    if (servingQuantity != null && servingQuantity > 0) {
      final servingName = _extractServingName(servingSize) ?? 'Portion';
      servings = ServingSize.generateFractions(servingName, servingQuantity);
    }

    return FoodItem(
      id: product['code'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.toString(),
      category: product['categories_tags']?.first?.toString() ?? 'food',
      caloriesPer100g: calories,
      proteinPer100g: protein,
      carbsPer100g: carbs,
      fatPer100g: fat,
      barcode: product['code'],
      brand: brand,
      imageUrl: imageUrl,
      servings: servings,
    );
  }

  /// Extract serving name from format "1 Becher (250g)" -> "Becher"
  String? _extractServingName(String? servingSize) {
    if (servingSize == null || servingSize.isEmpty) return null;
    // Remove parenthetical weight info and leading number
    var name = servingSize.replaceAll(RegExp(r'\s*\([^)]*\)\s*'), '').trim();
    // Remove leading numbers like "1 " or "2x "
    name = name.replaceAll(RegExp(r'^[\d.,]+\s*x?\s*'), '').trim();
    return name.isNotEmpty ? name : null;
  }

  double? _parseNutrient(Map<String, dynamic> nutrients, String key) {
    final value = nutrients[key];
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// Cache entry with expiration
class _CacheEntry {
  final List<FoodItem> results;
  final DateTime timestamp;

  _CacheEntry(this.results, this.timestamp);

  bool get isExpired =>
      DateTime.now().difference(timestamp) > OpenFoodFactsService._cacheDuration;
}
