import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/ui/components/repeat_meal_button.dart';

import '../helpers/test_services.dart';

void main() {
  testWidgets('repeated the latest breakfast with undo instead of the latest dinner', (tester) async {
    final nutrition = (await tester.runAsync(() => createLoadedNutritionProvider()))!;
    final settings = await createWidgetTestSettingsProvider(tester);
    final now = DateTime.now();
    await tester.runAsync(() async {
      for (final meal in ['breakfast', 'dinner']) {
        await nutrition.addFoodEntry(FoodEntry(id: meal, name: meal, calories: 120,
          protein: 3, carbs: 20, fat: 4, portionAmount: 80, portionUnit: NutritionUnit.gram,
          timestamp: now.subtract(Duration(days: meal == 'breakfast' ? 2 : 1)), meal: meal,),);
      }
    });
    await pumpTestApp(tester, const Scaffold(body: RepeatMealButton(meal: 'breakfast')),
      nutritionProvider: nutrition, settingsProvider: settings,);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.replay_outlined));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    final copied = nutrition.getEntriesForDate(now).single;
    expect(copied.meal, 'breakfast');
    expect(copied.portionAmount, 80);
    expect(copied.id, isNot('breakfast'));
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(nutrition.getEntriesForDate(now), isEmpty);
    expect(nutrition.entries, hasLength(2));
  });
}
