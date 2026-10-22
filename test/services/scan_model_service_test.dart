import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/services/scan_model_service.dart';
import 'package:sophis/services/label_intake_flow.dart';
import 'package:sophis/services/service_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('sophis/scan_models');
  const service = ScanModelService();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('ScanModelService', () {
    test('waited for installation completion before allowing scanning',
        () async {
      final installed = Completer<void>();
      MethodCall? request;
      messenger.setMockMethodCallHandler(channel, (call) async {
        request = call;
        await installed.future;
        return null;
      });
      var completed = false;
      final result = service.ensureAvailable(ScanModel.ocr).then((value) {
        completed = true;
        return value;
      });
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      expect(request?.method, 'ensureAvailable');
      expect(request?.arguments, {'model': 'ocr'});
      installed.complete();
      expect(await result, isA<Success<void>>());
    });

    test('allowed retry after a model download failed', () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.arguments, {'model': 'barcode'});
        if (++calls == 1) throw PlatformException(code: 'download_failed');
        return null;
      });
      final first = await service.ensureAvailable(ScanModel.barcode);
      expect(first, isA<Failure<void>>());
      expect((first as Failure<void>).errorType, ServiceErrorType.network);
      expect(
        await service.ensureAvailable(ScanModel.barcode),
        isA<Success<void>>(),
      );
      expect(calls, 2);
    });

    test('reported unavailable Google Play services separately', () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'play_services_unavailable');
      });
      final result = await service.ensureAvailable(ScanModel.ocr);
      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).errorType, ServiceErrorType.unknown);
      expect(result.message, contains('Google Play services'));
    });

    test('kept iOS scanning independent of Google Play services', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      messenger.setMockMethodCallHandler(channel, (_) async {
        fail('iOS must not request Android model installation');
      });
      expect(
        await service.ensureAvailable(ScanModel.ocr),
        isA<Success<void>>(),
      );
    });

    test('stopped label analysis when models were unavailable', () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'download_failed');
      });
      final flow = LabelIntakeFlow();
      final request = LabelIntakeRequest(
        imageFile: File('/missing-image.jpg'),
        idGenerator: () => 'unused',
      );
      final result = await flow.processImage(request);
      final draft = await flow.processDraftImage(request);
      expect(result, isA<Failure<LabelIntakeResult>>());
      expect(
        (result as Failure<LabelIntakeResult>).errorType,
        ServiceErrorType.network,
      );
      expect(draft.isFailure, isTrue);
    });
  });
}
