import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/ui/components/edit_food_entry_dialog.dart';
import 'package:sophis/ui/screens/food_diary_screen.dart';
import 'package:sophis/ui/screens/meal_detail_screen.dart';

import '../helpers/test_services.dart';

void main() {
  testWidgets('opened yesterday and copied only the selected entry into today',
      (tester) async {
    final nutrition =
        (await tester.runAsync(() => createLoadedNutritionProvider()))!;
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1, 12);
    final original = FoodEntry(
      id: 'yesterday-egg',
      name: 'Yesterday egg',
      calories: 90,
      protein: 6,
      carbs: 1,
      fat: 7,
      timestamp: yesterday,
      meal: 'lunch',
    );
    await tester.runAsync(() => nutrition.addFoodEntry(original));
    final settings = await createWidgetTestSettingsProvider(tester);
    await pumpTestApp(
      tester,
      const FoodDiaryScreen(),
      nutritionProvider: nutrition,
      settingsProvider: settings,
      locale: const Locale('en'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Yesterday egg'));
    await tester.tap(find.text('Yesterday egg'));
    await tester.pumpAndSettle();
    expect(find.byType(EditFoodEntryDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Yesterday egg'));
    await tester.pumpAndSettle();
    expect(find.byType(MealDetailScreen), findsNothing);
    expect(find.text('Edit Entry'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    await tester.ensureVisible(find.text('Copy to today'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Copy to today'));
      for (var attempt = 0; attempt < 100; attempt++) {
        if (nutrition.getEntriesForDate(now).isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(nutrition.getEntriesForDate(yesterday).single.id, original.id);
    final copy = nutrition.getEntriesForDate(now).single;
    expect(copy.id, isNot(original.id));
    expect(copy.name, original.name);
    expect(copy.calories, original.calories);
    expect(copy.meal, original.meal);
  });
}
