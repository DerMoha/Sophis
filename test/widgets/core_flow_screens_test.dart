import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/services/food_intake_controller.dart';
import 'package:sophis/ui/screens/add_food_screen.dart';
import 'package:sophis/ui/screens/water_screen.dart';

import '../helpers/test_services.dart';

void main() {
  group('Core flow screens', () {
    testWidgets('AddFoodScreen logged a manual food entry', (
      WidgetTester tester,
    ) async {
      final nutrition = await createLoadedWidgetNutritionProvider(tester);
      final settings = await createWidgetTestSettingsProvider(tester);
      final controller = FoodIntakeController(
        nutrition,
        now: () => DateTime(2026, 5, 30, 12),
        idGenerator: () => 'manual-entry-1',
      );

      await pumpTestApp(
        tester,
        const AddFoodScreen(meal: 'breakfast'),
        nutritionProvider: nutrition,
        settingsProvider: settings,
        foodIntakeController: controller,
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Manual entry'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Toast');
      await tester.enterText(find.byType(TextFormField).at(1), '250');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(nutrition.entries.single.id, 'manual-entry-1');
      expect(nutrition.entries.single.name, 'Toast');
      expect(nutrition.entries.single.calories, 250);
      expect(nutrition.entries.single.meal, 'breakfast');
    });

    testWidgets('WaterScreen added quick and custom water entries', (
      WidgetTester tester,
    ) async {
      final nutrition = await createLoadedWidgetNutritionProvider(tester);
      final settings = await createWidgetTestSettingsProvider(tester);

      await pumpTestApp(
        tester,
        const WaterScreen(),
        nutritionProvider: nutrition,
        settingsProvider: settings,
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Water'), findsOneWidget);

      await tester.tap(find.text('500 ml'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(nutrition.getTodayWaterTotal(), 500);

      await tester.enterText(find.byType(TextField), '125');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(nutrition.getTodayWaterTotal(), 625);
    });
  });
}
