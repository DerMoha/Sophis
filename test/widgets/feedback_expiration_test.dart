import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/ui/components/common/entry_feedback.dart';
import 'package:sophis/ui/theme/app_theme.dart';

import '../helpers/test_services.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('expired undo notification and used the theme dark=$dark', (tester) async {
      final nutrition = (await tester.runAsync(() => createLoadedNutritionProvider()))!;
      final settings = await createWidgetTestSettingsProvider(tester);
      final entry = FoodEntry(id: 'test', name: 'Toast', calories: 100,
        protein: 2, carbs: 20, fat: 1, meal: 'breakfast', timestamp: DateTime.now(),);
      await pumpTestApp(tester, Theme(data: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        child: Scaffold(body: Builder(builder: (context) => TextButton(
          onPressed: () => showFoodAddedFeedback(context, entry), child: const Text('Show'),
        ),),),), nutritionProvider: nutrition, settingsProvider: settings,);
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.persist, isFalse);
      expect(snack.duration, const Duration(seconds: 4));
      expect(snack.backgroundColor, isNull);
      final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
      expect(theme.snackBarTheme.actionTextColor, theme.snackBarTheme.contentTextStyle!.color);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });
  }
}
