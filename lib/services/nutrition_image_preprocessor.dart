import 'dart:io';

import 'package:image/image.dart' as img;

class NutritionImagePreprocessor {
  const NutritionImagePreprocessor();

  Future<File?> prepare(File source) async {
    final decoded = img.decodeImage(await source.readAsBytes());
    if (decoded == null) return null;

    final oriented = img.bakeOrientation(decoded);
    final grayscale = img.grayscale(oriented);
    final enhanced = img.adjustColor(grayscale, contrast: 1.18);
    final directory = await Directory.systemTemp.createTemp('sophis-label-ocr');
    final output = File('${directory.path}/enhanced.jpg');
    await output.writeAsBytes(img.encodeJpg(enhanced, quality: 96));
    return output;
  }

  Future<void> cleanUp(File? file) async {
    if (file == null) return;
    final directory = file.parent;
    if (directory.existsSync()) await directory.delete(recursive: true);
  }
}
