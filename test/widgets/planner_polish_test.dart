import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/meal_plan.dart';
import 'package:sophis/ui/screens/meal_planner_screen.dart';
import 'package:sophis/ui/screens/add_planned_meal_sheet.dart';
import 'package:sophis/ui/components/draft_guard.dart';
import 'package:sophis/ui/components/add_planned_meal_manual_entry_form.dart';

import '../helpers/test_services.dart';

void main() {
  testWidgets('kept a planned meal after failed swipe and restored its original on undo', (tester) async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final provider = await createLoadedWidgetNutritionProvider(tester, database: database);
    final settings = await createWidgetTestSettingsProvider(tester);
    final meal = PlannedMeal(id: 'undo-plan', date: DateTime.now(), meal: 'breakfast', name: 'Planned breakfast', calories: 250.5, protein: 10, carbs: 30, fat: 8);
    await tester.runAsync(() => provider.addPlannedMeal(meal));
    await tester.runAsync(() => database.customStatement("CREATE TRIGGER fail_plan_delete BEFORE DELETE ON planned_meals BEGIN SELECT RAISE(ABORT, 'simulated failure'); END"));
    await pumpTestApp(tester, const MealPlannerScreen(), nutritionProvider: provider, settingsProvider: settings);
    await tester.pumpAndSettle();
    final tile = find.byKey(const Key('undo-plan'));
    await tester.ensureVisible(tile);
    await tester.drag(tile, const Offset(-700, 0));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(provider.getPlannedMealsForDate(meal.date), hasLength(1));
    expect(tile, findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => database.customStatement('DROP TRIGGER fail_plan_delete'));
    await tester.drag(tile, const Offset(-700, 0));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(provider.getPlannedMealsForDate(meal.date), isEmpty);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    final restored = provider.getPlannedMealsForDate(meal.date).single;
    expect(restored.toJson(), meal.toJson());
    expect(tester.takeException(), isNull);
  });

  testWidgets('planner entry fit narrow German large text above keyboard', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final provider = await createLoadedWidgetNutritionProvider(tester);
    final settings = await createWidgetTestSettingsProvider(tester);
    await pumpTestApp(tester, Scaffold(body: Builder(builder: (context) => TextButton(
      onPressed: () => showDraftBottomSheet<void>(context: context, builder: (_) => AddPlannedMealSheet(date: DateTime.now())), child: const Text('Open'),
    ),),), nutritionProvider: provider, settingsProvider: settings, locale: const Locale('de'), textScaler: const TextScaler.linear(2),);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.widget<TabBar>(find.byType(TabBar)).controller!.animateTo(3);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final save = find.byType(ElevatedButton);
    await tester.scrollUntilVisible(save, 150,
      scrollable: find.descendant(of: find.byType(AddPlannedMealManualEntryForm), matching: find.byType(Scrollable)).first,);
    await tester.pumpAndSettle();
    expect(save.hitTestable(), findsOneWidget);
    expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(400));
  });
}
