import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/services/social/social_runtime.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });
  test(
      'included registered Firebase client options in ordinary iOS and Android builds',
      () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final ios = SocialRuntime.configuration();
    expect(ios?.options.projectId, 'sophis-d2953');
    expect(ios?.options.appId, '1:657623134154:ios:23417f8213e19b7d86a933');
    expect(ios?.emulatorHost, isNull);
    expect(ios?.enableAppCheck, isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final android = SocialRuntime.configuration();
    expect(android?.options.projectId, 'sophis-d2953');
    expect(android?.options.appId,
        '1:657623134154:android:63c8bd942f9fd2d486a933',);
    expect(android?.options.apiKey, isNot(ios?.options.apiKey));
  });
  test('did not infer registrations for unsupported desktop platforms', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(SocialRuntime.configuration(), isNull);
  });
}
