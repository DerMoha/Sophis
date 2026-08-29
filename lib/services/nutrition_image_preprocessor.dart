import 'dart:io';

import 'package:image/image.dart' as img;

class NutritionImagePreprocessor {
  const NutritionImagePreprocessor();

  Future<File?> prepare(File source) async {
    final candidates = await prepareCandidates(source);
    return candidates.firstOrNull;
  }

  /// Builds complementary OCR inputs from the same capture. The full-frame
  /// variant preserves headings and serving information, while the centered
  /// variant removes package artwork around the table. Both are deliberately
  /// grayscale rather than hard-thresholded so decimal separators and thin
  /// glyphs are not lost.
  Future<List<File>> prepareCandidates(File source) async {
    final decoded = img.decodeImage(await source.readAsBytes());
    if (decoded == null) return const [];

    final oriented = img.bakeOrientation(decoded);
    final normalized = _resizeForOcr(oriented);
    final directory = await Directory.systemTemp.createTemp('sophis-label-ocr');

    final full = _enhance(normalized.clone());
    final fullOutput = File('${directory.path}/enhanced-full.jpg');
    await fullOutput.writeAsBytes(img.encodeJpg(full, quality: 96));

    final cropWidth = (normalized.width * 0.9).round();
    final cropHeight = (normalized.height * 0.72).round();
    final centered = img.copyCrop(
      normalized,
      x: ((normalized.width - cropWidth) / 2).round(),
      y: ((normalized.height - cropHeight) / 2).round(),
      width: cropWidth,
      height: cropHeight,
    );
    final centeredOutput = File('${directory.path}/enhanced-centered.jpg');
    await centeredOutput.writeAsBytes(
      img.encodeJpg(_enhance(centered), quality: 96),
    );

    return [fullOutput, centeredOutput];
  }

  Future<void> cleanUp(File? file) async {
    if (file == null) return;
    final directory = file.parent;
    if (directory.existsSync()) await directory.delete(recursive: true);
  }

  Future<void> cleanUpCandidates(Iterable<File> files) async {
    final directories = files.map((file) => file.parent.path).toSet();
    for (final path in directories) {
      final directory = Directory(path);
      if (directory.existsSync()) await directory.delete(recursive: true);
    }
  }

  img.Image _resizeForOcr(img.Image source) {
    const maxDimension = 2400;
    if (source.width <= maxDimension && source.height <= maxDimension) {
      return source;
    }
    if (source.width >= source.height) {
      return img.copyResize(source, width: maxDimension);
    }
    return img.copyResize(source, height: maxDimension);
  }

  img.Image _enhance(img.Image source) {
    final grayscale = img.grayscale(source);
    return img.adjustColor(grayscale, contrast: 1.22);
  }
}
