import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:sophis/services/gemini_image_part_builder.dart';

void main() {
  group('GeminiImagePartBuilder', () {
    late Directory tempDirectory;
    const builder = GeminiImagePartBuilder();

    setUp(() async {
      tempDirectory =
          await Directory.systemTemp.createTemp('sophis-gemini-image-test-');
    });

    tearDown(() async {
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('normalizes decodable images to oriented JPEG data', () async {
      final image = img.Image(width: 2, height: 2);
      final source = File('${tempDirectory.path}/photo.png');
      await source.writeAsBytes(img.encodePng(image));

      final part = await builder.buildPart(source);
      final decoded = img.decodeImage(part.bytes);

      expect(part.mimeType, equals('image/jpeg'));
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(2));
      expect(decoded.height, equals(2));
    });

    test('preserves HEIC bytes with the detected HEIC MIME type', () async {
      final bytes = _heifContainerBytes('heic');
      final source = File('${tempDirectory.path}/photo.jpg');
      await source.writeAsBytes(bytes);

      final part = await builder.buildPart(source);

      expect(part.mimeType, equals('image/heic'));
      expect(part.bytes, orderedEquals(bytes));
    });

    test('preserves HEIF bytes with the detected HEIF MIME type', () async {
      final bytes = _heifContainerBytes('mif1');
      final source = File('${tempDirectory.path}/photo.heic');
      await source.writeAsBytes(bytes);

      final part = await builder.buildPart(source);

      expect(part.mimeType, equals('image/heif'));
      expect(part.bytes, orderedEquals(bytes));
    });

    test('rejects an unreadable unsupported image', () async {
      final source = File('${tempDirectory.path}/photo.bin');
      await source.writeAsBytes(const [1, 2, 3, 4]);

      expect(
        () => builder.buildPart(source),
        throwsA(isA<GeminiImageException>()),
      );
    });
  });
}

Uint8List _heifContainerBytes(String brand) {
  final brandBytes = brand.codeUnits;
  return Uint8List.fromList([
    0,
    0,
    0,
    24,
    0x66,
    0x74,
    0x79,
    0x70,
    ...brandBytes,
    0,
    0,
    0,
    0,
  ]);
}
