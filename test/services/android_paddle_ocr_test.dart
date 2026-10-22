import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/services/android_paddle_ocr.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('sophis/paddle_ocr');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('rejected a build without the experimental reader', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'paddle_not_built', message: 'Not enabled');
    });
    expect((await const AndroidPaddleOcr().prepare()).isFailure, isTrue);
  });

  test('verified the requested engine before benchmarking', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'engine': 'mlkit'},
    );
    expect((await const AndroidPaddleOcr().prepare()).isFailure, isTrue);
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        'engine': 'paddle',
        'recognizer': AndroidPaddleOcr.recognizer,
      },
    );
    expect((await const AndroidPaddleOcr().prepare()).isSuccess, isTrue);
  });

  test('preserved upper-limit text and model-derived word coordinates',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'recognize');
      final arguments = Map<String, dynamic>.from(call.arguments as Map);
      expect(arguments['recognizer'], AndroidPaddleOcr.recognizer);
      return [
        {
          'text': 'Ballaststoffe <0,5 g',
          'top': 20.0,
          'height': 10.0,
          'left': 10.0,
          'right': 100.0,
          'tokens': [
            {'text': 'Ballaststoffe', 'centerX': 30.0, 'centerY': 25.0},
            {'text': '<0,5', 'centerX': 80.0, 'centerY': 26.0},
            {'text': 'g', 'centerX': 96.0, 'centerY': 26.0},
          ],
        }
      ];
    });
    final lines = await const AndroidPaddleOcr().recognize(File('/test.jpg'));
    expect(lines.single.tokens[1].text, '<0,5');
    expect(lines.single.tokens[1].centerX, 80);
    expect(lines.single.tokens[1].centerY, 26);
  });

  test('surfaced recognition failure without changing readers', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'paddle_failed');
    });
    await expectLater(
      const AndroidPaddleOcr().recognize(File('/test.jpg')),
      throwsA(isA<PlatformException>()),
    );
  });

  test('passed table coordinates to native preprocessing', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'prepareTable');
      expect(call.arguments, {
        'path': '/test.jpg',
        'recognizer': AndroidPaddleOcr.recognizer,
        'left': 100.0,
        'top': 200.0,
        'right': 900.0,
        'bottom': 1200.0,
      });
      return ['/cache/table-0.jpg', '/cache/table-1.jpg', '/cache/table-2.jpg'];
    });
    final files = await const AndroidPaddleOcr().prepareTable(
      File('/test.jpg'),
      left: 100,
      top: 200,
      right: 900,
      bottom: 1200,
    );
    expect(files.map((file) => file.path), [
      '/cache/table-0.jpg',
      '/cache/table-1.jpg',
      '/cache/table-2.jpg',
    ]);
  });

  test('validated native image quality metrics', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'inspectImage');
      return [3072, 4096, 100.5, 400, 20];
    });
    expect(
      await const AndroidPaddleOcr().inspectImage(File('/test.jpg')),
      [3072.0, 4096.0, 100.5, 400.0, 20.0],
    );
    messenger.setMockMethodCallHandler(channel, (_) async => [1, 2]);
    await expectLater(
      const AndroidPaddleOcr().inspectImage(File('/test.jpg')),
      throwsFormatException,
    );
  });
}
