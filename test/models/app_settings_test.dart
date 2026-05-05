import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/app_settings.dart';

void main() {
  group('AppSettings', () {
    test('defaults progress photo lock to disabled', () {
      const settings = AppSettings();

      expect(settings.progressPhotoLockEnabled, isFalse);
    });

    test('serializes progress photo lock setting', () {
      const settings = AppSettings(progressPhotoLockEnabled: true);

      final restored = AppSettings.fromJson(settings.toJson());

      expect(restored.progressPhotoLockEnabled, isTrue);
    });

    test('defaults missing progress photo lock setting to disabled', () {
      final settings = AppSettings.fromJson(const <String, dynamic>{});

      expect(settings.progressPhotoLockEnabled, isFalse);
    });
  });
}
