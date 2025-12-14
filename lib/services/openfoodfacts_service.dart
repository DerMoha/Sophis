import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';

/// Service for searching food products via OpenFoodFacts API
class OpenFoodFactsService {
  static const _baseUrl = 'https://world.openfoodfacts.org';

  /// Search for food products by name
  Future<List<FoodItem>> search(String query) async {
    if (query.isEmpty) return [];

    try {
      final url = Uri.parse(
        '$_baseUrl/cgi/search.pl?search_terms=$query&search_simple=1&action=process&json=1&page_size=20',
      );
      
      final response = await http.get(url);
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final products = data['products'] as List? ?? [];

      return products
          .map((p) => _parseProduct(p))
          .where((item) => item != null)
          .cast<FoodItem>()
          .toList();
    } catch (e) {
      return [];
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

    return FoodItem(
      id: product['code'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.toString(),
      category: product['categories_tags']?.first?.toString() ?? 'food',
      caloriesPer100g: calories,
      proteinPer100g: protein,
      carbsPer100g: carbs,
      fatPer100g: fat,
      barcode: product['code'],
    );
  }

  double? _parseNutrient(Map<String, dynamic> nutrients, String key) {
    final value = nutrients[key];
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
