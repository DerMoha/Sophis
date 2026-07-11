import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/ui/screens/onboarding_screen.dart';

import '../helpers/test_services.dart';

void main() {
  testWidgets('skipped explanations but still offered goal setup', (
    tester,
  ) async {
    final settings = await createWidgetTestSettingsProvider(tester);

    await pumpTestApp(
      tester,
      const OnboardingScreen(),
      settingsProvider: settings,
    );
    await tester.pumpAndSettle();

    expect(find.text('Nutrition that fits your life'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-skip-explanations')));
    await tester.pumpAndSettle();

    expect(find.text('Would you like to set goals?'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-set-goals')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-skip-goals')), findsOneWidget);
    expect(settings.onboardingCompleted, isFalse);
  });

  testWidgets('allowed trying the app without creating goals', (tester) async {
    final settings = await createWidgetTestSettingsProvider(tester);

    await pumpTestApp(
      tester,
      const OnboardingScreen(),
      settingsProvider: settings,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding-skip-explanations')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-skip-goals')));
    await tester.pumpAndSettle();

    expect(settings.onboardingCompleted, isTrue);
  });

  testWidgets('kept the German onboarding usable with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = await createWidgetTestSettingsProvider(tester);

    await pumpTestApp(
      tester,
      const OnboardingScreen(),
      settingsProvider: settings,
      locale: const Locale('de'),
      textScaler: const TextScaler.linear(2),
    );
    await tester.pump();

    expect(find.text('Erklärungen überspringen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
