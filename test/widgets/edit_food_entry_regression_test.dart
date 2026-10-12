import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/ui/components/edit_food_entry_dialog.dart';

Future<void> openEditor(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('de'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: EditFoodEntryDialog(
        entry: FoodEntry(
          id: 'food',
          name: 'Food',
          calories: 78,
          protein: 13.75,
          carbs: 5,
          fat: 0.25,
          fiber: 0,
          timestamp: DateTime(2026),
          meal: 'breakfast',
          portionAmount: 125,
          portionUnit: NutritionUnit.gram,
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('reopened invalid manual values after collapsing',
      (tester) async {
    await openEditor(tester);
    await tester.tap(find.text('Ernährung'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(3), '-2');
    await tester.tap(find.text('Ernährung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.byType(EditFoodEntryDialog), findsOneWidget);
    expect(find.text('-2'), findsOneWidget);
    expect(find.text('Protein'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
  testWidgets('scaled from stable values and retained manual overrides',
      (tester) async {
    await openEditor(tester);
    final amount = find.byType(TextFormField).at(1);
    for (final value in ['1', '5', '17', '125']) {
      await tester.enterText(amount, value);
      await tester.pump();
    }
    await tester.tap(find.text('Ernährung'));
    await tester.pumpAndSettle();
    final protein = find.byType(TextFormField).at(3);
    expect(tester.widget<TextFormField>(protein).controller!.text, '13.75');
    await tester.enterText(protein, '20');
    await tester.enterText(amount, '250');
    await tester.pump();
    expect(tester.widget<TextFormField>(protein).controller!.text, '40.00');
    await tester.enterText(amount, '125');
    await tester.pump();
    expect(tester.widget<TextFormField>(protein).controller!.text, '20.00');
  });
}
