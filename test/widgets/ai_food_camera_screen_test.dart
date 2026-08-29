import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/ui/screens/ai_food_camera_screen.dart';

import '../helpers/test_services.dart';

void main() {
  testWidgets('AI screen opens Gemini settings when the key is missing', (
    tester,
  ) async {
    final settings = await createWidgetTestSettingsProvider(tester);

    await pumpTestApp(
      tester,
      const AIFoodCameraScreen(meal: 'breakfast'),
      settingsProvider: settings,
      locale: const Locale('de'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gemini-Key eintragen'), findsOneWidget);

    await tester.tap(find.text('Gemini-Key eintragen'));
    await tester.pumpAndSettle();

    expect(find.text('Gemini API Key'), findsOneWidget);
    expect(find.text('API Key eingeben'), findsOneWidget);
  });
}
