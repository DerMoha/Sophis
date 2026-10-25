import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/ui/screens/food_diary_screen.dart';
import 'package:sophis/ui/screens/meal_detail_screen.dart';
import 'package:sophis/ui/screens/home/modern/widgets/meal_section.dart';

import '../helpers/test_services.dart';

void main() {
  for (final surface in ['home', 'diary', 'meal']) {
    testWidgets('showed the same add choices from $surface', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final nutrition =
          (await tester.runAsync(() => createLoadedNutritionProvider()))!;
      final settings = await createWidgetTestSettingsProvider(tester);
      final Widget screen = switch (surface) {
        'home' => const Scaffold(
            body: MealSection(
              mealType: 'breakfast',
              title: 'Breakfast',
              icon: Icons.restaurant,
              showMacros: false,
            ),
          ),
        'diary' => const FoodDiaryScreen(),
        _ => MealDetailScreen(
            date: DateTime.now(),
            mealType: 'breakfast',
            mealTitle: 'Breakfast',
            mealIcon: Icons.restaurant,
          ),
      };
      await pumpTestApp(
        tester,
        screen,
        nutritionProvider: nutrition,
        settingsProvider: settings,
        textScaler: const TextScaler.linear(2),
      );
      await tester.pumpAndSettle();
      final add = surface == 'meal'
          ? find.byType(FloatingActionButton)
          : find.byIcon(Icons.add_circle_outline).first;
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      for (final label in [
        'Search food',
        'Barcode',
        'Nutrition label',
        'Food photo',
        'Manual entry',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      expect(find.text('Scan product'), findsNothing);
      expect(find.text('Optional AI'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
