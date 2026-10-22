import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';
import 'package:sophis/services/android_paddle_ocr.dart';

enum NutritionImageQualityIssue {
  tooSmall,
  tooDark,
  tooBright,
  lowContrast,
  tooBlurry,
}

class NutritionImageQualityResult {
  final NutritionImageQualityIssue? issue;

  const NutritionImageQualityResult({this.issue});

  bool get isAcceptable => issue == null;

  String get message => switch (issue) {
        NutritionImageQualityIssue.tooSmall =>
          'Move closer so the nutrition table fills the frame',
        NutritionImageQualityIssue.tooDark =>
          'The photo is too dark. Retake it in brighter, even light',
        NutritionImageQualityIssue.tooBright =>
          'The photo has too much glare. Tilt the package away from the light',
        NutritionImageQualityIssue.lowContrast =>
          'The text is too blurry or faint. Hold the camera steady and retake it',
        NutritionImageQualityIssue.tooBlurry =>
          'The text is out of focus. Tap the table, hold steady, and retake it',
        null => '',
      };
}

class NutritionImageQualityService {
  const NutritionImageQualityService();

  Future<NutritionImageQualityResult> inspect(File file) async {
    if (AndroidPaddleOcr.enabled) {
      return _evaluate(await const AndroidPaddleOcr().inspectImage(file));
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      return const NutritionImageQualityResult(
        issue: NutritionImageQualityIssue.tooSmall,
      );
    }

    final metrics = await compute(_measureImageQuality, bytes);
    if (metrics == null) {
      final mimeType =
          lookupMimeType('', headerBytes: bytes) ?? lookupMimeType(file.path);
      if (mimeType == 'image/heic' || mimeType == 'image/heif') {
        // package:image cannot decode HEIC/HEIF, but iOS and ML Kit can still
        // process these native camera/gallery images. Do not reject them as
        // undersized before OCR gets a chance to handle them.
        return const NutritionImageQualityResult();
      }
      return const NutritionImageQualityResult(
        issue: NutritionImageQualityIssue.tooSmall,
      );
    }

    return _evaluate(metrics);
  }

  NutritionImageQualityResult _evaluate(List<double> metrics) {
    if (metrics[0] < 700 || metrics[1] < 500) {
      return const NutritionImageQualityResult(
        issue: NutritionImageQualityIssue.tooSmall,
      );
    }

    final mean = metrics[2];
    final variance = metrics[3];
    final sharpness = metrics[4];
    if (mean < 35) {
      return const NutritionImageQualityResult(
        issue: NutritionImageQualityIssue.tooDark,
      );
    }
    if (mean > 245) {
      return const NutritionImageQualityResult(
        issue: NutritionImageQualityIssue.tooBright,
      );
    }
    if (variance < 180) {
      return const NutritionImageQualityResult(
        issue: NutritionImageQualityIssue.lowContrast,
      );
    }
    if (sharpness < 9.0) {
      return const NutritionImageQualityResult(
        issue: NutritionImageQualityIssue.tooBlurry,
      );
    }
    return const NutritionImageQualityResult();
  }
}

List<double>? _measureImageQuality(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  final cropWidth = (oriented.width * 0.9).round();
  final cropHeight = (oriented.height * 0.76).round();
  final sampleCrop = img.copyCrop(
    oriented,
    x: ((oriented.width - cropWidth) / 2).round(),
    y: ((oriented.height * 0.46) - cropHeight / 2)
        .round()
        .clamp(0, oriented.height - cropHeight),
    width: cropWidth,
    height: cropHeight,
  );
  final sample = img.grayscale(img.copyResize(sampleCrop, width: 240));
  var sum = 0.0;
  var sumSquares = 0.0;
  var count = 0;
  for (final pixel in sample) {
    final luminance = img.getLuminance(pixel);
    sum += luminance;
    sumSquares += luminance * luminance;
    count++;
  }
  final mean = sum / count;
  final variance = sumSquares / count - mean * mean;

  var laplacianSum = 0.0;
  var laplacianCount = 0;
  for (var y = 1; y < sample.height - 1; y++) {
    for (var x = 1; x < sample.width - 1; x++) {
      final center = img.getLuminance(sample.getPixel(x, y));
      final laplacian = center * 4 -
          img.getLuminance(sample.getPixel(x - 1, y)) -
          img.getLuminance(sample.getPixel(x + 1, y)) -
          img.getLuminance(sample.getPixel(x, y - 1)) -
          img.getLuminance(sample.getPixel(x, y + 1));
      laplacianSum += laplacian.abs();
      laplacianCount++;
    }
  }

  return [
    oriented.width.toDouble(),
    oriented.height.toDouble(),
    mean,
    variance,
    laplacianSum / laplacianCount,
  ];
}
