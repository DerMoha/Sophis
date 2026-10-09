import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/ui/components/settings/api_key_guide_dialog.dart';

import '../helpers/test_services.dart';

void main() {
  for (final locale in ['en', 'de']) {
    testWidgets(
        'kept the $locale API key guide usable on narrow screens with large text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpTestApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const ApiKeyGuideDialog(),
              ),
              child: const Text('Open guide'),
            ),
          ),
        ),
        locale: Locale(locale),
        textScaler: const TextScaler.linear(2),
      );
      await tester.tap(find.text('Open guide'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final close = find.widgetWithText(
        TextButton,
        locale == 'en' ? 'Got it' : 'Verstanden',
      );
      expect(close, findsOneWidget);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byType(ApiKeyGuideDialog), findsNothing);
    });
  }
}
