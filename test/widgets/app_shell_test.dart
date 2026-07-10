import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/ui/screens/home_screen.dart';

import '../helpers/test_services.dart';

void main() {
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
    expect(find.text('Food Diary'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Add Food'), findsOneWidget);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Planning'), findsOneWidget);
    expect(find.text('Tracking'), findsOneWidget);
    expect(find.text('Meal Planner'), findsOneWidget);

    await tester.tap(find.text('Today').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Food'));
    await tester.pumpAndSettle();
    expect(find.text('Search food'), findsOneWidget);
    expect(find.text('Scan barcode'), findsOneWidget);
    expect(find.text('Manual entry'), findsOneWidget);
    expect(find.text('Optional AI'), findsOneWidget);
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
