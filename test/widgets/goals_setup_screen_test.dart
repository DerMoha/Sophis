import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/ui/screens/goals_setup_screen.dart';

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

    final weightField = find.byType(TextField).first;
    final weightTextField = tester.widget<TextField>(weightField);

    expect(
      weightTextField.keyboardType,
      const TextInputType.numberWithOptions(decimal: true),
    );

    await tester.enterText(weightField, '72,5');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(nutrition.profile?.weight, 72.5);
  });
}
