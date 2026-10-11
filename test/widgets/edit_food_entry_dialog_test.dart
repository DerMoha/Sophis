import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/ui/components/edit_food_entry_dialog.dart';

void main() {
  testWidgets('scaled weight and nutrition and preserved portion metadata',
      (tester) async {
    final entry = FoodEntry(
      id: 'granola',
      name: 'Granola (100g)',
      calories: 400,
      protein: 10,
      carbs: 60,
      fat: 14,
      fiber: 8,
      timestamp: DateTime(2026),
      meal: 'breakfast',
      portionAmount: 100,
      portionUnit: NutritionUnit.gram,
      sourceFoodId: 'source',
    );
    FoodEntry? saved;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                    onPressed: () async {
                      saved = await showDialog<FoodEntry>(
                          context: context,
                          builder: (_) => EditFoodEntryDialog(entry: entry));
                    },
                    child: const Text('edit'),
                  ))),
    ));
    await tester.tap(find.text('edit'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
    await tester.enterText(find.byType(TextFormField).at(1), '150,5');
    await tester.pump();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(saved?.portionAmount, 150.5);
    expect(saved?.calories, 602);
    expect(saved?.fiber, 12.04);
    expect(saved?.sourceFoodId, 'source');
    expect(saved?.name, 'Granola (150.5g)');
    expect(tester.takeException(), isNull);
  });
}
