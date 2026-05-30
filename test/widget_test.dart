import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/ui/screens/home_screen.dart';

import 'helpers/test_services.dart';

void main() {
  testWidgets('Home screen showed onboarding state', (
    WidgetTester tester,
  ) async {
    final nutrition = await createLoadedWidgetNutritionProvider(tester);
    final settings = await createWidgetTestSettingsProvider(tester);
    nutrition.attachSettingsProvider(settings);

    await pumpTestApp(
      tester,
      const HomeScreen(),
      nutritionProvider: nutrition,
      settingsProvider: settings,
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Sophis'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Welcome to Sophis'), findsOneWidget);

    expect(find.text('Set Goals'), findsOneWidget);
  });
}
