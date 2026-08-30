import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';

enum NutritionImageQualityIssue { tooSmall, tooDark, tooBright, lowContrast }

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
        null => '',
      };
}

class NutritionImageQualityService {
  const NutritionImageQualityService();

  Future<NutritionImageQualityResult> inspect(File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      return const NutritionImageQualityResult(
        issue: NutritionImageQualityIssue.tooSmall,
      );
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
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

    if (decoded.width < 700 || decoded.height < 500) {
      return const NutritionImageQualityResult(
        issue: NutritionImageQualityIssue.tooSmall,
      );
    }

    final sample = img.copyResize(decoded, width: 160);
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
    return const NutritionImageQualityResult();
  }
}
