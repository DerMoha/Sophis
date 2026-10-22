import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/ui/components/organic/progress.dart';
import 'package:sophis/ui/screens/home_screen.dart';
import 'package:sophis/ui/screens/home/modern/widgets/calorie_hero_card.dart';
import 'package:sophis/ui/screens/home/modern/widgets/macros_card.dart';
import 'package:sophis/ui/screens/macro_details_screen.dart';

import '../helpers/test_services.dart';

void main() {
  testWidgets('calorie summary showed burned calories and the adjusted goal',
      (tester) async {
    await pumpTestApp(
      tester,
      const Scaffold(
        body: CalorieHeroCard(
          consumed: 900,
          baseGoal: 2200,
          effectiveGoal: 2520,
          remaining: 1620,
          progress: 900 / 2520,
          burnedCalories: 320,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('+320'), findsOneWidget);
    expect(find.text('/ 2520'), findsOneWidget);
    expect(find.text('2200'), findsOneWidget);
  });

  testWidgets('Today kept breakfast visible below the compact summary',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final nutrition = await createLoadedWidgetNutritionProvider(tester);
    final settings = await createWidgetTestSettingsProvider(tester);
    nutrition.attachSettingsProvider(settings);
    await nutrition.setGoals(NutritionGoals(calories: 2200));
    await pumpTestApp(
      tester,
      const HomeScreen(),
      nutritionProvider: nutrition,
      settingsProvider: settings,
    );
    await tester.pumpAndSettle();

    expect(find.text('Calories'), findsOneWidget);
    final hero = find.byType(CalorieHeroCard);
    expect(
      find.descendant(
        of: hero,
        matching: find.byType(LinearProgressIndicator),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: hero, matching: find.byType(RadialProgress)),
      findsWidgets,
    );
    expect(
      find.descendant(of: hero, matching: find.byType(MacrosCard)),
      findsOneWidget,
    );
    expect(find.text('+0 kcal burned'), findsNothing);
    expect(find.text('Macronutrients'), findsNothing);
    expect(find.text('Quick Actions'), findsOneWidget);
    final breakfast = find.text('Breakfast');
    expect(breakfast, findsOneWidget);
    expect(
      tester.getBottomLeft(breakfast).dy,
      lessThan(tester.getTopLeft(find.byType(NavigationBar)).dy),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(MacrosCard));
    await tester.pumpAndSettle();
    expect(find.byType(MacroDetailsScreen), findsOneWidget);
  });

  testWidgets('AppShell remained available without nutrition goals', (
    tester,
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
    await tester.pumpAndSettle();

    expect(find.text('Diary'), findsWidgets);
    expect(find.text('Add Food'), findsOneWidget);

    await tester.tap(find.text('Diary').last);
    await tester.pumpAndSettle();

    expect(find.text('Diary'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppShell exposed focused navigation and Add Food choices', (
    tester,
  ) async {
    final nutrition = await createLoadedWidgetNutritionProvider(tester);
    final settings = await createWidgetTestSettingsProvider(tester);
    nutrition.attachSettingsProvider(settings);
    await nutrition.setGoals(NutritionGoals(calories: 2000));

    await pumpTestApp(
      tester,
      const HomeScreen(),
      nutritionProvider: nutrition,
      settingsProvider: settings,
    );
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Diary'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Add Food'), findsOneWidget);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Planning'), findsOneWidget);
    expect(find.text('Log entries'), findsOneWidget);
    expect(find.text('Meal Planner'), findsOneWidget);

    await tester.tap(find.text('Today').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Food'));
    await tester.pumpAndSettle();
    expect(find.text('Search food'), findsOneWidget);
    expect(find.text('Scan product'), findsOneWidget);
    expect(find.text('Manual entry'), findsOneWidget);
    expect(find.text('Photograph food'), findsOneWidget);
    expect(find.text('Optional AI'), findsNothing);
  });

  testWidgets('AppShell supported German at 200% text on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final nutrition = await createLoadedWidgetNutritionProvider(tester);
    final settings = await createWidgetTestSettingsProvider(tester);
    nutrition.attachSettingsProvider(settings);
    await nutrition.setGoals(NutritionGoals(calories: 2000));

    await pumpTestApp(
      tester,
      const HomeScreen(),
      nutritionProvider: nutrition,
      settingsProvider: settings,
      locale: const Locale('de'),
      textScaler: const TextScaler.linear(2),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Mehr'), findsOneWidget);
  });
}
