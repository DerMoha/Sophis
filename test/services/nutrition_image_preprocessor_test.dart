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

  test('creates full-frame and centered OCR candidates', () async {
    final directory = await Directory.systemTemp.createTemp('label-source');
    final source = File('${directory.path}/source.png');
    final image = img.Image(width: 3000, height: 4000);
    await source.writeAsBytes(img.encodePng(image));
    const preprocessor = NutritionImagePreprocessor();

    final candidates = await preprocessor.prepareCandidates(source);

    expect(candidates, hasLength(2));
    final full = img.decodeImage(await candidates.first.readAsBytes())!;
    final centered = img.decodeImage(await candidates.last.readAsBytes())!;
    expect(full.height, 2400);
    expect(centered.width, lessThan(full.width));
    expect(centered.height, lessThan(full.height));
    await preprocessor.cleanUpCandidates(candidates);
    expect(candidates.every((file) => !file.existsSync()), isTrue);
    await directory.delete(recursive: true);
  });
}
