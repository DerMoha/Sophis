import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/ui/screens/water_screen.dart';
import 'package:sophis/ui/components/add_planned_meal_manual_entry_form.dart';

import '../helpers/test_services.dart';

void main() {
  testWidgets('kept the water draft after a failed write and retried once',
      (tester) async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final provider =
        await createLoadedWidgetNutritionProvider(tester, database: database);
    final settings = await createWidgetTestSettingsProvider(tester);
    await tester.runAsync(
      () => database.customStatement('''
      CREATE TRIGGER fail_water BEFORE INSERT ON water_logs
      BEGIN SELECT RAISE(ABORT, 'simulated water failure'); END
    '''),
    );
    await pumpTestApp(
      tester,
      const WaterScreen(),
      nutritionProvider: provider,
      settingsProvider: settings,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '125,5');
    final add = find.widgetWithText(ElevatedButton, 'Add');
    await tester.tap(add);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('125,5'), findsOneWidget);
    expect(provider.waterEntries, isEmpty);
    expect(find.text('Not saved. Please try again.'), findsOneWidget);
    await tester
        .runAsync(() => database.customStatement('DROP TRIGGER fail_water'));
    await tester.tap(add);
    await tester.tap(add);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(provider.waterEntries, hasLength(1));
    expect(provider.waterEntries.single.amountMl, 125.5);
    expect(find.text('125,5'), findsNothing);
  });
  testWidgets('kept a planned meal draft on failure and committed one retry',
      (tester) async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final provider =
        await createLoadedWidgetNutritionProvider(tester, database: database);
    final settings = await createWidgetTestSettingsProvider(tester);
    var saves = 0;
    await tester.runAsync(() => database.customStatement(
        "CREATE TRIGGER fail_plan BEFORE INSERT ON planned_meals BEGIN SELECT RAISE(ABORT, 'simulated failure'); END",),);
    await pumpTestApp(
      tester,
      Scaffold(
        body: AddPlannedMealManualEntryForm(
          date: DateTime(2026, 10, 18),
          mealType: 'breakfast',
          onSaved: () => saves++,
        ),
      ),
      nutritionProvider: provider,
      settingsProvider: settings,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Test meal');
    await tester.enterText(find.byType(TextFormField).at(1), '250,5');
    final add = find.byType(ElevatedButton);
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),);
    await tester.pumpAndSettle();
    expect(saves, 0);
    expect(find.text('250,5'), findsOneWidget);
    expect(find.text('Not saved. Please try again.'), findsOneWidget);
    expect(provider.getPlannedMealsForDate(DateTime(2026, 10, 18)), isEmpty);
    await tester
        .runAsync(() => database.customStatement('DROP TRIGGER fail_plan'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.tap(add);
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),);
    await tester.pumpAndSettle();
    expect(saves, 1);
    final meals = provider.getPlannedMealsForDate(DateTime(2026, 10, 18));
    expect(meals, hasLength(1));
    expect(meals.single.calories, 250.5);
  });
}
