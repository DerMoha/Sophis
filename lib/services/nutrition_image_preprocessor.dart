import 'dart:io';
import 'package:flutter/foundation.dart';
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
    final bytes = await source.readAsBytes();
    final encodedCandidates = await compute(_prepareCandidateBytes, bytes);
    if (encodedCandidates.isEmpty) return const [];
    final directory = await Directory.systemTemp.createTemp('sophis-label-ocr');

    final fullOutput = File('${directory.path}/enhanced-full.jpg');
    await fullOutput.writeAsBytes(encodedCandidates.first, flush: true);
    final centeredOutput = File('${directory.path}/enhanced-centered.jpg');
    await centeredOutput.writeAsBytes(encodedCandidates.last, flush: true);

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
}

List<Uint8List> _prepareCandidateBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return const [];

  final oriented = img.bakeOrientation(decoded);
  final normalized = _resizeForOcr(oriented);
  final full = _enhanceForOcr(normalized.clone());

  // The camera guide sits slightly above vertical center. This crop matches
  // that framing while retaining enough surrounding text for table headings.
  final cropWidth = (normalized.width * 0.9).round();
  final cropHeight = (normalized.height * 0.76).round();
  final desiredCenterY = (normalized.height * 0.46).round();
  final cropY = (desiredCenterY - cropHeight ~/ 2).clamp(
    0,
    normalized.height - cropHeight,
  );
  final centered = img.copyCrop(
    normalized,
    x: ((normalized.width - cropWidth) / 2).round(),
    y: cropY,
    width: cropWidth,
    height: cropHeight,
  );

  return [
    Uint8List.fromList(img.encodeJpg(full, quality: 94)),
    Uint8List.fromList(
      img.encodeJpg(_enhanceForOcr(centered), quality: 94),
    ),
  ];
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

img.Image _enhanceForOcr(img.Image source) {
  final grayscale = img.grayscale(source);
  final contrasted = img.adjustColor(grayscale, contrast: 1.24);
  return img.convolution(
    contrasted,
    filter: const [0, -1, 0, -1, 5, -1, 0, -1, 0],
    amount: 0.32,
  );
}
