import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/water_entry.dart';

void main() {
  group('WaterEntry', () {
    test('creates instance with required fields', () {
      final timestamp = DateTime(2026, 1, 2, 8, 30);
      final entry = WaterEntry(
        id: 'water-1',
        amountMl: 250,
        timestamp: timestamp,
      );

      expect(entry.id, equals('water-1'));
      expect(entry.amountMl, equals(250));
      expect(entry.timestamp, equals(timestamp));
    });

    test('toJson serializes all fields', () {
      final timestamp = DateTime(2026, 1, 2, 8, 30);
      final entry = WaterEntry(
        id: 'water-1',
        amountMl: 250,
        timestamp: timestamp,
      );

      final json = entry.toJson();

      expect(json['id'], equals('water-1'));
      expect(json['amountMl'], equals(250));
      expect(json['timestamp'], equals(timestamp.toIso8601String()));
    });

    test('fromJson deserializes all fields', () {
      final json = {
        'id': 'water-1',
        'amountMl': 250.0,
        'timestamp': '2026-01-02T08:30:00.000',
      };

      final entry = WaterEntry.fromJson(json);

      expect(entry.id, equals('water-1'));
      expect(entry.amountMl, equals(250.0));
      expect(entry.timestamp, equals(DateTime(2026, 1, 2, 8, 30)));
    });

    test('fromJson handles int amountMl', () {
      final json = {
        'id': 'water-1',
        'amountMl': 250,
        'timestamp': '2026-01-02T08:30:00.000',
      };

      final entry = WaterEntry.fromJson(json);

      expect(entry.amountMl, isA<double>());
      expect(entry.amountMl, equals(250.0));
    });

    test('json roundtrip preserves all data', () {
      final original = WaterEntry(
        id: 'water-1',
        amountMl: 350.5,
        timestamp: DateTime(2026, 3, 15, 14, 20),
      );

      final json = original.toJson();
      final restored = WaterEntry.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.amountMl, equals(original.amountMl));
      expect(restored.timestamp, equals(original.timestamp));
    });
  });
}
