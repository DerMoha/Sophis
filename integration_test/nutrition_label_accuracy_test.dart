import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sophis/models/nutrition_label_draft.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/services/label_intake_flow.dart';

// Scoreboard for real label photos (scanner v2 plan, P0).
//
// Photos live in test/fixtures/nutrition_labels/photos/ (gitignored) next to
// the committed manifest.json. Serve that folder before running:
//   python3 -m http.server 8769 -d test/fixtures/nutrition_labels/photos
//   flutter test integration_test/nutrition_label_accuracy_test.dart \
//     -d <simulator> --dart-define=REAL_LABEL_PHOTOS=true
//
// The run records what the user would see on the review screen: the full
// result when the flow succeeds, otherwise the partial draft. It only fails
// on errors, or on wrong values with --dart-define=STRICT_LABEL_SCORE=true.
const _host = 'http://127.0.0.1:8769';
const _fields = ['calories', 'protein', 'carbs', 'fat', 'fiber'];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('REAL_LABEL_PHOTOS');
  const strict = bool.fromEnvironment('STRICT_LABEL_SCORE');

  testWidgets(
    'scored real nutrition label photos',
    (tester) async {
      final client = HttpClient();
      final directory = await Directory.systemTemp.createTemp('label-score-');
      final rows = <Map<String, Object?>>[];
      try {
        final manifest =
            (jsonDecode(await _get(client, 'manifest.json')) as List)
                .cast<Map<String, dynamic>>();
        for (final testCase in manifest) {
          final name = testCase['photo'] as String;
          final file = File('${directory.path}/$name');
          await file.writeAsBytes(await _getBytes(client, name));
          rows.add(await _score(testCase, file));
        }
      } finally {
        client.close();
        await directory.delete(recursive: true);
      }

      final total = rows.length * _fields.length;
      final correct =
          rows.fold<int>(0, (sum, row) => sum + (row['correct']! as int));
      final complete = rows.where((row) => row['complete'] == true).length;
      // A wrong prefilled value is worse than a missing one; track it apart.
      final wrong = rows.fold<int>(
        0,
        (sum, row) =>
            sum +
            (row['fields']! as Map<String, String>)
                .values
                .where((result) => result.startsWith('wrong'))
                .length,
      );
      for (final row in rows) {
        debugPrint('SCORE_JSON:${jsonEncode(row)}');
      }
      debugPrint(
        'SCORE_SUMMARY: fields $correct/$total, wrong $wrong, complete '
        'scans $complete/${rows.length}',
      );
      if (strict) expect(correct, total);
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Future<Map<String, Object?>> _score(
  Map<String, dynamic> testCase,
  File file,
) async {
  final name = testCase['photo'] as String;
  final expected = (testCase['expected'] as Map).cast<String, Object?>();
  final flow = LabelIntakeFlow();
  final stopwatch = Stopwatch()..start();
  try {
    final request =
        LabelIntakeRequest(imageFile: file, idGenerator: () => name);
    if (const bool.fromEnvironment('DUMP_LABEL_TABLES')) {
      try {
        final tables = await const MethodChannel('sophis/nutrition_text')
            .invokeMapMethod<String, dynamic>(
          'recognizeDocument',
          {'path': file.path},
        );
        debugPrint('TABLE_JSON:${jsonEncode({
              'photo': name,
              'tables': tables?['tables'],
            })}');
      } on PlatformException catch (error) {
        debugPrint('TABLE_JSON:${jsonEncode({
              'photo': name,
              'error': error.code,
            })}');
      }
    }
    final result = await flow.processImage(request);
    final intake = result.valueOrNull;
    final draft = intake != null
        ? NutritionLabelDraft.fromResult(intake.label)
        : (await flow.processDraftImage(request)).valueOrNull;
    stopwatch.stop();

    final read = <String, Object?>{
      'calories': draft?.caloriesPer100,
      'protein': draft?.proteinPer100,
      'carbs': draft?.carbsPer100,
      'fat': draft?.fatPer100,
      'fiber': draft?.fiberPer100,
    };
    final fieldResults = <String, String>{};
    for (final field in _fields) {
      fieldResults[field] = _compare(
        expected[field],
        read[field] as double?,
        upperBound: draft?.upperBoundFields.contains(
              NutritionLabelField.values.byName(field),
            ) ??
            false,
      );
    }
    final expectedUnit = testCase['unit'] as String? ?? 'gram';
    return {
      'photo': name,
      'complete': intake != null,
      'highConfidence': intake?.validation.isHighConfidence ?? false,
      'issues': intake?.validation.issues.map((i) => i.name).toList(),
      'correct': fieldResults.values.where((r) => r == 'ok').length,
      'fields': fieldResults,
      'read': read,
      'unitOk': draft?.nutritionUnit.name == expectedUnit,
      'servingOk': testCase['serving'] == null ||
          draft?.servingAmount == (testCase['serving'] as num).toDouble(),
      'seconds': stopwatch.elapsedMilliseconds / 1000,
    };
  } finally {
    flow.dispose();
  }
}

/// ok, wrong (with the value read), or missing.
String _compare(Object? expected, double? read, {required bool upperBound}) {
  if (expected == null) return read == null ? 'ok' : 'wrong:$read';
  if (read == null) return 'missing';
  if (expected is String && expected.startsWith('<')) {
    final bound = double.parse(expected.substring(1));
    return upperBound && (read - bound).abs() < 0.01
        ? 'ok'
        : 'wrong:${upperBound ? '<' : ''}$read';
  }
  final value = (expected as num).toDouble();
  return (read - value).abs() < 0.01 ? 'ok' : 'wrong:$read';
}

Future<String> _get(HttpClient client, String path) async =>
    utf8.decode(await _getBytes(client, path));

Future<List<int>> _getBytes(HttpClient client, String path) async {
  final request = await client.getUrl(Uri.parse('$_host/$path'));
  final response = await request.close();
  expect(response.statusCode, 200, reason: path);
  final bytes = <int>[];
  await for (final chunk in response) {
    bytes.addAll(chunk);
  }
  return bytes;
}
