import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/label_intake_flow.dart';
import 'package:sophis/services/nutrition_image_preprocessor.dart';

// Serve the original photos locally on port 8769 before running on iOS Simulator.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const enabled = bool.fromEnvironment('REAL_LABEL_PHOTOS');

  const cases = {
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
          if (const bool.fromEnvironment('CAPTURE_LABEL_OCR')) {
            final recognizer =
                TextRecognizer(script: TextRecognitionScript.latin);
            const preprocessor = NutritionImagePreprocessor();
            final candidates = await preprocessor.prepareCandidates(file);
            for (final candidate in [file, ...candidates]) {
              final recognized =
                  await recognizer.processImage(InputImage.fromFile(candidate));
              debugPrint('OCR_JSON:${jsonEncode({
                    'photo': name,
                    'candidate': candidate.path,
                    'lines': [
                      for (final block in recognized.blocks)
                        for (final line in block.lines)
                          {
                            'text': line.text,
                            'top': line.boundingBox.top,
                            'bottom': line.boundingBox.bottom,
                            'tokens': [
                              for (final e in line.elements)
                                {
                                  'text': e.text,
                                  'centerX': e.boundingBox.center.dx,
                                  'centerY': e.boundingBox.center.dy,
                                },
                            ],
                          },
                    ],
                  })}');
            }
            await recognizer.close();
            await preprocessor.cleanUpCandidates(candidates);
          }
          final result = await flow.processImage(
            LabelIntakeRequest(imageFile: file, idGenerator: () => name),
            onProgress: (progress) => debugPrint('$name: ${progress.name}'),
          );
          final intake = result.valueOrNull;
          debugPrint('$name result: $result');
          if (intake == null) {
            debugPrint('RESULT_JSON:${jsonEncode({
                  'photo': name,
                  'failure': result.toString(),
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
            // The label prints <0.5 g fiber. Numeric matching alone does not
            // verify preservation of that bound; report this separately.
          }
        } finally {
          flow.dispose();
          client.close();
          await directory.delete(recursive: true);
        }
      },
      skip: !enabled,
    );
  }
}
