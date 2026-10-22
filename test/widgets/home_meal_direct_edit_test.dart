import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/ui/components/edit_food_entry_dialog.dart';
import 'package:sophis/ui/screens/home/modern/widgets/meal_section.dart';
import 'package:sophis/ui/screens/meal_detail_screen.dart';

import '../helpers/test_services.dart';

void main() {
  for (final meal in ['breakfast', 'lunch', 'dinner']) {
    testWidgets('edited $meal entry directly from home', (tester) async {
      final provider = (await tester.runAsync(() => createLoadedNutritionProvider()))!;
      final settings = await createWidgetTestSettingsProvider(tester);
      await tester.runAsync(() => provider.addFoodEntry(FoodEntry(
        id: 'direct-entry', name: 'Test food', calories: 100, protein: 5,
        carbs: 10, fat: 4, timestamp: DateTime.now(), meal: meal,
      ),),);
      await pumpTestApp(tester, Scaffold(body: SingleChildScrollView(child:
        MealSection(mealType: meal, title: meal, icon: Icons.restaurant, showMacros: false),
      ),), nutritionProvider: provider, settingsProvider: settings,);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test food'));
      await tester.pumpAndSettle();
      expect(find.byType(EditFoodEntryDialog), findsOneWidget);
      expect(find.byType(MealDetailScreen), findsNothing);
      await tester.enterText(find.byType(TextFormField).first, 'Updated food');
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(find.byType(EditFoodEntryDialog), findsNothing);
      expect(find.text('Updated food'), findsOneWidget);
      expect(provider.getEntriesByMeal(meal).single.name, 'Updated food');
    });
  }
}
