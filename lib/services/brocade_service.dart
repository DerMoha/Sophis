import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'service_result.dart';

/// Service for looking up product names via Brocade.io
/// Used as a fallback when OpenFoodFacts has no match.
/// Returns product name/brand only — no nutrition data.
class BrocadeService {
  static const _baseUrl = 'https://www.brocade.io/api';

  /// Look up a product by barcode. Returns name and brand if found.
  Future<ServiceResult<BrocadeProduct>> lookup(String barcode) async {
    try {
      final url = Uri.parse('$_baseUrl/$barcode');
      final response = await http.get(url).timeout(
            const Duration(seconds: 5),
          );

      if (response.statusCode != 200) {
        return const Failure(ServiceErrorType.notFound, 'Product not found');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final name = data['name']?.toString();
      if (name == null || name.isEmpty) {
        return const Failure(ServiceErrorType.notFound, 'Product not found');
      }

      return Success(
        BrocadeProduct(
          name: name,
          brand: data['brand']?.toString(),
        ),
      );
    } on SocketException catch (e) {
      debugPrint('Brocade lookup network error for "$barcode": $e');
      return Failure(ServiceErrorType.network, e.message);
    } on TimeoutException {
      debugPrint('Brocade lookup timeout for "$barcode"');
      return const Failure(ServiceErrorType.network, 'Request timed out');
    } catch (e) {
      debugPrint('Brocade lookup failed for "$barcode": $e');
      return Failure(ServiceErrorType.unknown, e.toString());
    }
  }
}

class BrocadeProduct {
  final String name;
  final String? brand;

  const BrocadeProduct({required this.name, this.brand});
}
