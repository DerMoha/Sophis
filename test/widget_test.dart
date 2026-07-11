import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/ui/screens/home_screen.dart';

import 'helpers/test_services.dart';

void main() {
  testWidgets('Home screen allowed food logging without goals', (
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
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Food Diary'), findsWidgets);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Add Food'), findsOneWidget);
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Set Goals'), findsNothing);
  });
}
