import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart' show Response;
import '../models/food_item.dart';
import 'service_result.dart';

class OpenFoodFactsWriteService {
  static const _submitUrl =
      'https://world.openfoodfacts.org/cgi/product_jpc.pl';
  static const _timeout = Duration(seconds: 15);

  Future<ServiceResult<void>> submitProduct(
    FoodItem item, {
    String? userId,
    String? password,
  }) async {
    try {
      final body = <String, String>{
        'code': item.barcode ?? item.id,
        'product_name': item.name,
        'brands': item.brand ?? '',
        'nutriment_energy-kcal_100g': item.caloriesPer100g.toStringAsFixed(0),
        'nutriment_proteins_100g': item.proteinPer100g.toStringAsFixed(1),
        'nutriment_carbohydrates_100g': item.carbsPer100g.toStringAsFixed(1),
        'nutriment_fat_100g': item.fatPer100g.toStringAsFixed(1),
        'comment': 'Submitted via Sophis App',
      };

      if (userId != null &&
          userId.isNotEmpty &&
          password != null &&
          password.isNotEmpty) {
        body['user_id'] = userId;
        body['password'] = password;
      }

      final request = http.Request('POST', Uri.parse(_submitUrl));
      request.bodyFields = body;

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('application/json')) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final status = data['status']?.toString() ?? '';
          final statusVerbose = data['status_verbose']?.toString() ?? '';

          if (status == '0' || statusVerbose.contains('error')) {
            final errorMessage = statusVerbose.isNotEmpty
                ? statusVerbose
                : 'Failed to submit product';

            if (errorMessage.toLowerCase().contains('authentication') ||
                errorMessage.toLowerCase().contains('password') ||
                errorMessage.toLowerCase().contains('invalid')) {
              return const Failure(
                ServiceErrorType.authFailed,
                'Invalid OpenFoodFacts credentials',
              );
            }
            return Failure(ServiceErrorType.unknown, errorMessage);
          }
          return const Success(null);
        } else {
          if (response.body.contains('status=0') ||
              response.body.contains('error')) {
            if (response.body.contains('authentication') ||
                response.body.contains('password') ||
                response.body.contains('invalid')) {
              return const Failure(
                ServiceErrorType.authFailed,
                'Invalid OpenFoodFacts credentials',
              );
            }
            return Failure(
              ServiceErrorType.unknown,
              'Submission failed: ${response.body.substring(0, response.body.length.clamp(0, 200))}',
            );
          }
          return const Success(null);
        }
      } else if (response.statusCode == 429) {
        return const Failure(
          ServiceErrorType.rateLimited,
          'Too many requests, try again later',
        );
      } else {
        return Failure(
          ServiceErrorType.unknown,
          'Server returned status ${response.statusCode}',
        );
      }
    } on SocketException catch (e) {
      debugPrint('OpenFoodFacts write network error: $e');
      return Failure(ServiceErrorType.network, e.message);
    } on TimeoutException {
      debugPrint('OpenFoodFacts write timeout');
      return const Failure(ServiceErrorType.network, 'Request timed out');
    } on FormatException catch (e) {
      debugPrint('OpenFoodFacts write parse error: $e');
      return Failure(ServiceErrorType.parseError, e.message);
    } catch (e) {
      debugPrint('OpenFoodFacts write failed: $e');
      return Failure(ServiceErrorType.unknown, e.toString());
    }
  }
}
