import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/ui/screens/goals_setup_screen.dart';
import 'package:sophis/models/nutrition_goals.dart';

import '../helpers/test_services.dart';

void main() {
  testWidgets('accepts comma decimal weight in German locale', (
    WidgetTester tester,
  ) async {
    final nutrition = await createLoadedWidgetNutritionProvider(tester);
    final settings = await createWidgetTestSettingsProvider(tester);

    await pumpTestApp(
      tester,
      const GoalsSetupScreen(),
      nutritionProvider: nutrition,
      settingsProvider: settings,
      locale: const Locale('de'),
    );
    await tester.pumpAndSettle();

    final weightField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Gewicht (kg)',
    );
    final targetField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Zielgewicht (kg)',
    );
    expect(tester.getTopLeft(targetField).dy, lessThan(400));
    await tester.enterText(targetField, '68,5');
    await tester.ensureVisible(weightField);
    final weightTextField = tester.widget<TextField>(weightField);

    expect(
      weightTextField.keyboardType,
      const TextInputType.numberWithOptions(decimal: true),
    );

    await tester.enterText(weightField, '72,5');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(nutrition.profile?.weight, 72.5);
    expect(nutrition.profile?.targetWeight, 68.5);
  });
  testWidgets(
      'kept target weight visible and macro fields readable on narrow screens',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final nutrition = await createLoadedWidgetNutritionProvider(tester);
    await nutrition.setGoals(NutritionGoals(calories: 2000));
    final settings = await createWidgetTestSettingsProvider(tester);
    await pumpTestApp(
      tester,
      const GoalsSetupScreen(),
      nutritionProvider: nutrition,
      locale: const Locale('de'),
      settingsProvider: settings,
      textScaler: const TextScaler.linear(1.5),
    );
    await tester.pumpAndSettle();
    expect(find.text('Zielgewicht (kg)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Makronährstoffe'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
