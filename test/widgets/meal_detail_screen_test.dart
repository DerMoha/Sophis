import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/food_entry.dart';
import 'package:sophis/ui/components/edit_food_entry_dialog.dart';
import 'package:sophis/ui/screens/meal_detail_screen.dart';

import '../helpers/test_services.dart';

void main() {
  testWidgets(
      'kept meal controls compact and delete visible above system inset',
      (tester) async {
    tester.view.physicalSize = const Size(393, 650);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.reset);
    final nutrition =
        (await tester.runAsync(() => createLoadedNutritionProvider()))!;
    await tester.runAsync(
      () => nutrition.addFoodEntry(
        FoodEntry(
          id: 'egg',
          name: 'Fried egg (50g)',
          calories: 90,
          protein: 6,
          carbs: 1,
          fat: 7,
          timestamp: DateTime.now(),
          meal: 'lunch',
        ),
      ),
    );
    final settings = await createWidgetTestSettingsProvider(tester);
    await pumpTestApp(
      tester,
      const MealDetailScreen(
        mealType: 'lunch',
        mealTitle: 'Lunch',
        mealIcon: Icons.sunny,
      ),
      nutritionProvider: nutrition,
      settingsProvider: settings,
      locale: const Locale('de'),
      textScaler: const TextScaler.linear(1.3),
    );
    await tester.pumpAndSettle();
    expect(find.text('+10%'), findsNothing);
    expect(find.text('90 kcal'), findsOneWidget);
    await tester.tap(find.text('Fried egg (50g)'));
    await tester.pumpAndSettle();
    expect(find.byType(EditFoodEntryDialog), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Fried egg (50g)'));
    await tester.pumpAndSettle();
    expect(find.text('+10%'), findsOneWidget);
    final delete = find.text('Löschen');
    expect(delete.hitTestable(), findsOneWidget);
    expect(tester.getBottomLeft(delete).dy, lessThan(626));
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => tester.tap(delete));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsNothing);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(nutrition.entries, isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Rückgängig').hitTestable(), findsOneWidget);
    await tester.runAsync(() => tester.tap(find.text('Rückgängig')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(nutrition.entries.single.id, 'egg');
    expect(nutrition.entries.single.meal, 'lunch');
  });
}
