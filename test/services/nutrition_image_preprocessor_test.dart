import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sophis/services/nutrition_image_preprocessor.dart';

void main() {
  test('creates and cleans up an OCR-enhanced image', () async {
    final directory = await Directory.systemTemp.createTemp('label-source');
    final source = File('${directory.path}/source.png');
    final image = img.Image(width: 800, height: 600);
    await source.writeAsBytes(img.encodePng(image));
    const preprocessor = NutritionImagePreprocessor();

    final prepared = await preprocessor.prepare(source);

    expect(prepared, isNotNull);
    expect(prepared!.existsSync(), isTrue);
    expect(img.decodeImage(await prepared.readAsBytes()), isNotNull);
    await preprocessor.cleanUp(prepared);
    expect(prepared.existsSync(), isFalse);
    await directory.delete(recursive: true);
  });
}
