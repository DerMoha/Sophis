import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sophis/services/nutrition_image_quality_service.dart';

void main() {
  test('rejects undersized captures', () async {
    final file = await _writeImage(img.Image(width: 200, height: 200));
    final result = await const NutritionImageQualityService().inspect(file);
    expect(result.issue, NutritionImageQualityIssue.tooSmall);
    await file.delete();
  });

  test('accepts a high-contrast document-sized capture', () async {
    final image = img.Image(width: 800, height: 600);
    img.fill(image, color: img.ColorRgb8(250, 250, 250));
    for (var x = 0; x < image.width; x += 20) {
      img.fillRect(
        image,
        x1: x,
        y1: 0,
        x2: x + 9,
        y2: image.height - 1,
        color: img.ColorRgb8(20, 20, 20),
      );
    }
    final file = await _writeImage(image);
    final result = await const NutritionImageQualityService().inspect(file);
    expect(result.isAcceptable, isTrue);
    await file.delete();
  });

  test('rejects a strongly blurred high-contrast capture', () async {
    final image = img.Image(width: 800, height: 600);
    img.fill(image, color: img.ColorRgb8(245, 245, 245));
    for (var y = 80; y < 520; y += 36) {
      img.fillRect(
        image,
        x1: 80,
        y1: y,
        x2: 720,
        y2: y + 10,
        color: img.ColorRgb8(20, 20, 20),
      );
    }
    final blurred = img.gaussianBlur(image, radius: 14);
    final file = await _writeImage(blurred);

    final result = await const NutritionImageQualityService().inspect(file);

    expect(result.issue, NutritionImageQualityIssue.tooBlurry);
    await file.delete();
  });

  test('allows HEIC files that the Dart image decoder cannot inspect',
      () async {
    final directory = await Directory.systemTemp.createTemp('label-quality');
    final file = File('${directory.path}/fixture.heic');
    await file.writeAsBytes(_heifContainerBytes('heic'));

    final result = await const NutritionImageQualityService().inspect(file);

    expect(result.isAcceptable, isTrue);
    await directory.delete(recursive: true);
  });
}

Future<File> _writeImage(img.Image image) async {
  final directory = await Directory.systemTemp.createTemp('label-quality');
  final file = File('${directory.path}/fixture.png');
  await file.writeAsBytes(img.encodePng(image));
  return file;
}

Uint8List _heifContainerBytes(String brand) {
  return Uint8List.fromList([
    0,
    0,
    0,
    24,
    0x66,
    0x74,
    0x79,
    0x70,
    ...brand.codeUnits,
    0,
    0,
    0,
    0,
  ]);
}
