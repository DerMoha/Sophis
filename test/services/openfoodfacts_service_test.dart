import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/services/openfoodfacts_service.dart';
import 'package:sophis/services/service_result.dart';

void main() {
  group('OpenFoodFactsService', () {
    test('search with empty query returns empty success', () async {
      final service = OpenFoodFactsService(
        client: MockClient((_) async {
          fail('HTTP client should not be called for empty queries');
        }),
      );

      final result = await service.search('');

      expect(result.isSuccess, isTrue);
      expect(result.value, isEmpty);
    });

    test('search requests only needed fields and parses products', () async {
      final client = MockClient((request) async {
        expect(request.method, equals('GET'));
        expect(request.url.host, equals('de.openfoodfacts.org'));
        expect(request.url.path, equals('/cgi/search.pl'));
        expect(request.url.queryParameters['search_terms'], equals('apple'));
        expect(
          request.url.queryParameters['fields'],
          contains('product_name_en'),
        );
        expect(
          request.url.queryParameters['fields'],
          contains('image_front_url'),
        );
        expect(request.headers['Accept'], equals('application/json'));

        return http.Response(
          jsonEncode(<String, dynamic>{
            'products': <Map<String, dynamic>>[
              <String, dynamic>{
                'code': '1234567890',
                'product_name': 'Apple Slices',
                'brands': 'Orchard Co',
                'categories_tags': <String>['en:fruit'],
                'serving_size': '1 pack (80g)',
                'serving_quantity': 80,
                'nutriments': <String, dynamic>{
                  'energy-kcal_100g': 52,
                  'proteins_100g': 0.3,
                  'carbohydrates_100g': 14,
                  'fat_100g': 0.2,
                },
              },
            ],
          }),
          200,
        );
      });
      final service = OpenFoodFactsService(client: client);

      final result = await service.search(' apple ');

      expect(result.isSuccess, isTrue);
      expect(result.value, hasLength(1));
      expect(result.value.first.name, equals('Apple Slices'));
      expect(result.value.first.brand, equals('Orchard Co'));
      expect(result.value.first.caloriesPer100g, equals(52));
      expect(result.value.first.servings, isNotEmpty);
    });

    test('search falls back to world when DE search returns no results',
        () async {
      final requestedHosts = <String>[];
      final client = MockClient((request) async {
        requestedHosts.add(request.url.host);

        if (request.url.host == 'de.openfoodfacts.org') {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'products': <Map<String, dynamic>>[],
            }),
            200,
          );
        }

        if (request.url.host == 'world.openfoodfacts.org') {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'products': <Map<String, dynamic>>[
                <String, dynamic>{
                  'code': '9876543210',
                  'product_name': 'Chocolate Pudding',
                  'brands': 'World Foods',
                  'categories_tags': <String>['en:desserts'],
                  'nutriments': <String, dynamic>{
                    'energy-kcal_100g': 115,
                    'proteins_100g': 3.5,
                    'carbohydrates_100g': 17.0,
                    'fat_100g': 3.2,
                  },
                },
              ],
            }),
            200,
          );
        }

        fail('Unexpected host ${request.url.host}');
      });
      final service = OpenFoodFactsService(client: client);

      final result = await service.search('Chocolate pudding');

      expect(result.isSuccess, isTrue);
      expect(result.value, hasLength(1));
      expect(result.value.first.name, equals('Chocolate Pudding'));
      expect(
        requestedHosts,
        equals(<String>['de.openfoodfacts.org', 'world.openfoodfacts.org']),
      );
    });

    test('search tolerates empty categories tags lists', () async {
      final service = OpenFoodFactsService(
        client: MockClient((_) async {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'products': <Map<String, dynamic>>[
                <String, dynamic>{
                  'code': '4000000000001',
                  'product_name_de': 'Schokoladenpudding',
                  'categories_tags': <String>[],
                  'nutriments': <String, dynamic>{
                    'energy-kcal_100g': 120,
                    'proteins_100g': 3.2,
                    'carbohydrates_100g': 18.5,
                    'fat_100g': 3.8,
                  },
                },
              ],
            }),
            200,
          );
        }),
      );

      final result = await service.search('Schokoladenpudding');

      expect(result.isSuccess, isTrue);
      expect(result.value, hasLength(1));
      expect(result.value.first.name, equals('Schokoladenpudding'));
      expect(result.value.first.category, equals('food'));
    });

    test('search falls back to Portion for unit-only serving labels', () async {
      final service = OpenFoodFactsService(
        client: MockClient((_) async {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'products': <Map<String, dynamic>>[
                <String, dynamic>{
                  'code': '4000000000002',
                  'product_name_de': 'Schokoladenpudding',
                  'serving_size': '200g',
                  'serving_quantity': 200,
                  'nutriments': <String, dynamic>{
                    'energy-kcal_100g': 76,
                    'proteins_100g': 5,
                    'carbohydrates_100g': 3,
                    'fat_100g': 1,
                  },
                },
              ],
            }),
            200,
          );
        }),
      );

      final result = await service.search('Schokoladenpudding');

      expect(result.isSuccess, isTrue);
      expect(result.value, hasLength(1));
      expect(result.value.first.servings, isNotEmpty);
      expect(
        result.value.first.servings
            .firstWhere((serving) => serving.multiplier == 1)
            .name,
        equals('1 Portion'),
      );
    });

    test('search returns rate limited failure for 429 responses', () async {
      final service = OpenFoodFactsService(
        client: MockClient((_) async => http.Response('{}', 429)),
      );

      final result = await service.search('apple');
      final failure = result as Failure<List<FoodItem>>;

      expect(result.isFailure, isTrue);
      expect(failure.errorType, equals(ServiceErrorType.rateLimited));
    });

    test('search returns timeout failure when request exceeds timeout',
        () async {
      final service = OpenFoodFactsService(
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response('{}', 200);
        }),
        requestTimeout: const Duration(milliseconds: 10),
      );

      final result = await service.search('apple');
      final failure = result as Failure<List<FoodItem>>;

      expect(result.isFailure, isTrue);
      expect(failure.errorType, equals(ServiceErrorType.network));
      expect(failure.message, equals('Request timed out'));
    });
  });
}
