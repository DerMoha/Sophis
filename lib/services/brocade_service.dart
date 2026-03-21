import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for looking up product names via Brocade.io
/// Used as a fallback when OpenFoodFacts has no match.
/// Returns product name/brand only — no nutrition data.
class BrocadeService {
  static const _baseUrl = 'https://www.brocade.io/api';

  /// Look up a product by barcode. Returns name and brand if found.
  Future<BrocadeProduct?> lookup(String barcode) async {
    try {
      final url = Uri.parse('$_baseUrl/$barcode');
      final response = await http.get(url).timeout(
            const Duration(seconds: 5),
          );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final name = data['name']?.toString();
      if (name == null || name.isEmpty) return null;

      return BrocadeProduct(
        name: name,
        brand: data['brand']?.toString(),
      );
    } catch (e) {
      return null;
    }
  }
}

class BrocadeProduct {
  final String name;
  final String? brand;

  const BrocadeProduct({required this.name, this.brand});
}
