import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:sophis/services/nutrition_ocr_document.dart';
import 'package:sophis/services/service_result.dart';

/// Developer-only alternative. A failed Paddle request never silently uses
/// ML Kit, so a benchmark result always belongs to the selected engine.
class AndroidPaddleOcr {
  static const _channel = MethodChannel('sophis/paddle_ocr');
  static const recognizer = String.fromEnvironment(
    'PADDLE_RECOGNIZER',
    defaultValue: 'v6',
  );
  static bool get enabled =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      const bool.fromEnvironment('PADDLE_OCR');

  const AndroidPaddleOcr();

  Future<List<double>> inspectImage(File file) async {
    final metrics = await _channel.invokeListMethod<num>(
      'inspectImage',
      {'path': file.path, 'recognizer': recognizer},
    );
    if (metrics == null || metrics.length != 5) {
      throw const FormatException('Missing native image quality metrics');
    }
    return metrics.map((value) => value.toDouble()).toList();
  }

  Future<List<File>> prepareTable(
    File file, {
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) async {
    final paths = await _channel.invokeListMethod<String>(
      'prepareTable',
      {
        'path': file.path,
        'recognizer': recognizer,
        'left': left,
        'top': top,
        'right': right,
        'bottom': bottom,
      },
    );
    return (paths ?? []).map(File.new).toList();
  }

  Future<ServiceResult<void>> prepare() async {
    try {
      final info = await _channel.invokeMapMethod<String, dynamic>(
        'prepare',
        {'recognizer': recognizer},
      ).timeout(const Duration(seconds: 60));
      if (info?['engine'] != 'paddle' || info?['recognizer'] != recognizer) {
        return const Failure(
          ServiceErrorType.unknown,
          'Unexpected OCR engine.',
        );
      }
      return const Success(null);
    } on MissingPluginException {
      return const Failure(
        ServiceErrorType.unknown,
        'This build does not include experimental PaddleOCR.',
      );
    } on PlatformException catch (error) {
      return Failure(
        ServiceErrorType.unknown,
        'Could not prepare experimental PaddleOCR: ${error.message}',
      );
    } on TimeoutException {
      return const Failure(
        ServiceErrorType.unknown,
        'PaddleOCR preparation timed out.',
      );
    }
  }

  Future<List<NutritionOcrLine>> recognize(File file) async {
    final raw = await _channel.invokeListMethod<dynamic>(
      'recognize',
      {'path': file.path, 'recognizer': recognizer},
    ).timeout(const Duration(seconds: 20));
    return (raw ?? []).map((value) {
      final line = Map<String, dynamic>.from(value as Map);
      return NutritionOcrLine(
        text: line['text'] as String,
        top: (line['top'] as num).toDouble(),
        height: (line['height'] as num).toDouble(),
        left: (line['left'] as num).toDouble(),
        right: (line['right'] as num).toDouble(),
        tokens: (line['tokens'] as List<dynamic>).map((value) {
          final token = Map<String, dynamic>.from(value as Map);
          return NutritionOcrToken(
            text: token['text'] as String,
            centerX: (token['centerX'] as num).toDouble(),
            centerY: (token['centerY'] as num).toDouble(),
          );
        }).toList(),
      );
    }).toList()
      ..sort((a, b) => a.top.compareTo(b.top));
  }
}
