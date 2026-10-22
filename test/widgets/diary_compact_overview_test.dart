import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/ui/screens/food_diary_screen.dart';

import '../helpers/test_services.dart';

void main() {
  testWidgets('kept reuse tools collapsed and breakfast reachable in the diary', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final nutrition = (await tester.runAsync(() => createLoadedNutritionProvider()))!;
    final settings = await createWidgetTestSettingsProvider(tester);
    await tester.runAsync(() => nutrition.addFoodEntry(FoodEntry(id: 'skyr', name: 'Skyr',
      calories: 112, protein: 20, carbs: 7, fat: 0, meal: 'breakfast', timestamp: DateTime.now(),),),);
    await pumpTestApp(tester, const FoodDiaryScreen(), nutritionProvider: nutrition,
      settingsProvider: settings, locale: const Locale('de'),);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    expect(find.text('Letzte Mahlzeit wiederholen'), findsNothing);
    expect(find.text('Gestern kopieren'), findsNothing);
    expect(find.text('Skyr').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
