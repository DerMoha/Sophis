import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:sophis/services/android_paddle_ocr.dart';
import 'package:sophis/services/nutrition_ocr_document.dart';
import 'package:sophis/services/nutrition_table_region.dart';

class NutritionImagePreprocessor {
  const NutritionImagePreprocessor();

  Future<File?> prepare(File source) async {
    final candidates = await prepareCandidates(source);
    return candidates.firstOrNull;
  }

  /// Crops around the detected nutrient table and tries color, grayscale and
  /// inverted text. Falls back to full-frame/centered crops when no table is
  /// located. The original capture remains a separate candidate in the flow.
  Future<List<File>> prepareCandidates(
    File source, {
    List<NutritionOcrLine> lines = const [],
  }) async {
    final region = NutritionTableRegion.locate(lines);
    if (AndroidPaddleOcr.enabled && region != null) {
      return const AndroidPaddleOcr().prepareTable(
        source,
        left: region.left,
        top: region.top,
        right: region.right,
        bottom: region.bottom,
      );
    }
    final bytes = await source.readAsBytes();
    final encodedCandidates = region == null
        ? await compute(_prepareCandidateBytes, bytes)
        : await compute(
            _prepareTableBytes,
            (bytes, region.left, region.top, region.right, region.bottom),
          );
    if (encodedCandidates.isEmpty) return const [];
    final directory = await Directory.systemTemp.createTemp('sophis-label-ocr');

    final outputs = <File>[];
    for (var index = 0; index < encodedCandidates.length; index++) {
      final output = File(
        '${directory.path}/${region == null ? 'full' : 'table'}-$index.jpg',
      );
      await output.writeAsBytes(encodedCandidates[index], flush: true);
      outputs.add(output);
    }
    return outputs;
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

List<Uint8List> _prepareTableBytes(
  (Uint8List, double, double, double, double) request,
) {
  final decoded = img.decodeImage(request.$1);
  if (decoded == null) return const [];
  final source = img.bakeOrientation(decoded);
  final left = request.$2.round().clamp(0, source.width - 1);
  final top = request.$3.round().clamp(0, source.height - 1);
  final right = request.$4.round().clamp(left + 1, source.width);
  final bottom = request.$5.round().clamp(top + 1, source.height);
  final cropped = img.copyCrop(
    source,
    x: left,
    y: top,
    width: right - left,
    height: bottom - top,
  );
  // OCR sees the table at a readable scale, not a downsampled whole package.
  final table = img.copyResize(
    cropped,
    width: 1800,
    interpolation: img.Interpolation.cubic,
  );
  final gray = img.grayscale(table.clone());
  return [
    Uint8List.fromList(img.encodeJpg(table, quality: 98)),
    Uint8List.fromList(img.encodeJpg(gray, quality: 98)),
    Uint8List.fromList(img.encodeJpg(img.invert(gray), quality: 98)),
  ];
}
