import 'dart:io';

import 'package:image/image.dart' as img;

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
    final decoded = img.decodeImage(await file.readAsBytes());
    if (decoded == null || decoded.width < 700 || decoded.height < 500) {
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
