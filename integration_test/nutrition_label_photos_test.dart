import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image/image.dart' as img;

import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/services/android_paddle_ocr.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/label_intake_flow.dart';

// Serve originals on port 8769. Android needs: adb reverse tcp:8769 tcp:8769.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const enabled = bool.fromEnvironment('REAL_LABEL_PHOTOS');

  const cases = {
    'MVIMG_20261011_091005.jpg': [62.0, 11.0, 4.0, 0.2, 0.0],
    'MVIMG_20261011_090958.jpg': [62.0, 11.0, 4.0, 0.2, 0.0],
    'MVIMG_20261011_171032.jpg': [64.0, 5.0, 7.2, 1.7, 0.5],
    'MVIMG_20261011_171031.jpg': [64.0, 5.0, 7.2, 1.7, 0.5],
    'MVIMG_20261011_171019.jpg': [70.0, 4.5, 5.2, 3.5, 0.0],
    'MVIMG_20261011_171017.jpg': [95.0, 6.9, 12.0, 0.7, 6.5],
    'MVIMG_20261011_171024.jpg': [47.0, 0.0, 12.0, 0.0, 0.0],
  };
  for (final entry in cases.entries) {
    final name = entry.key;
    final expected = entry.value;
    testWidgets(
      'read real label photo $name',
      (tester) async {
        final client = HttpClient();
        final directory = await Directory.systemTemp.createTemp('label-photo-');
        final flow = LabelIntakeFlow();
        try {
          final request =
              await client.getUrl(Uri.parse('http://127.0.0.1:8769/$name'));
          final response = await request.close();
          expect(response.statusCode, 200);
          final file = File('${directory.path}/$name');
          await response.pipe(file.openWrite());
          const maxDimension = int.fromEnvironment('PHOTO_MAX_DIMENSION');
          if (maxDimension > 0) {
            final decoded =
                img.bakeOrientation(img.decodeImage(await file.readAsBytes())!);
            final resized = decoded.width >= decoded.height
                ? img.copyResize(decoded, width: maxDimension)
                : img.copyResize(decoded, height: maxDimension);
            await file.writeAsBytes(img.encodeJpg(resized, quality: 95));
          }
          final stopwatch = Stopwatch()..start();
          final result = await flow.processImage(
            LabelIntakeRequest(imageFile: file, idGenerator: () => name),
            onProgress: (progress) => debugPrint('$name: ${progress.name}'),
          );
          final intake = result.valueOrNull;
          debugPrint('$name result: $result');
          if (intake == null) {
            debugPrint('RESULT_JSON:${jsonEncode({
                  'photo': name,
                  'engine': AndroidPaddleOcr.enabled
                      ? 'paddle-${AndroidPaddleOcr.recognizer}'
                      : defaultTargetPlatform.name,
                  'failure': result is Failure<LabelIntakeResult>
                      ? result.message
                      : result.toString(),
                })}');
          }
          expect(intake, isNotNull);
          final label = intake!.label;
          debugPrint('$name: kcal=${label.caloriesPer100g}, '
              'protein=${label.proteinPer100g}, carbs=${label.carbsPer100g}, '
              'fat=${label.fatPer100g}, fiber=${label.fiberPer100g}, '
              'serving=${label.servingSizeG}, '
              'confidence=${intake.validation.isHighConfidence}, '
              'issues=${intake.validation.issues}');
          debugPrint('RESULT_JSON:${jsonEncode({
                'photo': name,
                'engine': AndroidPaddleOcr.enabled
                    ? 'paddle-${AndroidPaddleOcr.recognizer}'
                    : defaultTargetPlatform.name,
                'elapsedMs': stopwatch.elapsedMilliseconds,
                'upperBoundFields':
                    label.upperBoundFields.map((field) => field.name).toList(),
                'values': [
                  label.caloriesPer100g,
                  label.proteinPer100g,
                  label.carbsPer100g,
                  label.fatPer100g,
                  label.fiberPer100g,
                ],
                'unit': label.nutritionUnit.name,
                'presentFields':
                    label.presentFields.map((field) => field.name).toList(),
                'serving': label.servingSizeG,
                'confidence': intake.validation.isHighConfidence,
                'issues': intake.validation.issues
                    .map((issue) => issue.name)
                    .toList(),
              })}');
          expect(
            [
              label.caloriesPer100g,
              label.proteinPer100g,
              label.carbsPer100g,
              label.fatPer100g,
              label.fiberPer100g,
            ],
            expected,
          );
          final isDrink = name.endsWith('171032.jpg') ||
              name.endsWith('171031.jpg') ||
              name.endsWith('171024.jpg');
          expect(
            label.nutritionUnit,
            isDrink ? NutritionUnit.milliliter : NutritionUnit.gram,
          );
          if (name.endsWith('171024.jpg')) {
            expect(
              label.presentFields.contains(NutritionLabelField.fiber),
              isFalse,
            );
          } else {
            expect(
              label.presentFields.contains(NutritionLabelField.fiber),
              isTrue,
            );
          }
          if (name.endsWith('171032.jpg') || name.endsWith('171031.jpg')) {
            expect(label.servingSizeG, 250);
            expect(label.upperBoundFields, contains(NutritionLabelField.fiber));
            expect(intake.validation.isHighConfidence, isFalse);
          }
        } finally {
          await debugPrintDone;
          flow.dispose();
          client.close();
          await directory.delete(recursive: true);
        }
      },
      skip: !enabled,
    );
  }
}
