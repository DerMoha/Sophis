import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/services/label_intake_flow.dart';
import 'package:sophis/services/nutrition_image_quality_service.dart';
import 'package:sophis/services/scan_model_service.dart';
import 'package:sophis/services/service_result.dart';

class _ReadyModels extends ScanModelService {
  @override
  Future<ServiceResult<void>> ensureAvailable(ScanModel model) async =>
      const Success(null);
}

class _PendingQuality extends NutritionImageQualityService {
  final started = Completer<void>();
  final completion = Completer<NutritionImageQualityResult>();

  @override
  Future<NutritionImageQualityResult> inspect(File file) {
    started.complete();
    return completion.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final draft in [false, true]) {
    test('stopped ${draft ? 'draft' : 'full'} scanning after disposal',
        () async {
      const channel = MethodChannel('google_mlkit_text_recognizer');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var recognitions = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'vision#closeTextRecognizer') recognitions++;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final quality = _PendingQuality();
      final flow = LabelIntakeFlow(
        qualityService: quality,
        scanModels: _ReadyModels(),
      );
      final request = LabelIntakeRequest(
        imageFile: File('/unused.jpg'),
        idGenerator: () => 'cancelled',
      );
      final pending =
          draft ? flow.processDraftImage(request) : flow.processImage(request);
      await quality.started.future;
      flow.dispose();
      quality.completion.complete(const NutritionImageQualityResult());
      final result = await pending;
      expect(result.isFailure, isTrue);
      expect(recognitions, 0);
    });
  }
}
