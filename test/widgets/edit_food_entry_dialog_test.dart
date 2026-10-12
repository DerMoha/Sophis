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
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await showDialog<FoodEntry>(
                  context: context,
                  builder: (_) => EditFoodEntryDialog(entry: entry),
                );
              },
              child: const Text('edit'),
            ),
          ),
        ),
      ),
    );
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
  testWidgets('kept name and portion visible while manual nutrition scrolled',
      (tester) async {
    tester.view.physicalSize = const Size(393, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final entry = FoodEntry(
      id: 'skyr',
      name: 'Milbona SKYR NATUR (1 Portion)',
      calories: 78,
      protein: 13.75,
      carbs: 5,
      fat: 0.25,
      fiber: 0,
      timestamp: DateTime(2026),
      meal: 'breakfast',
      portionAmount: 125,
      portionUnit: NutritionUnit.gram,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(393, 700),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(body: EditFoodEntryDialog(entry: entry)),
        ),
      ),
    );
    final name = find.byType(TextFormField).first;
    final initialTop = tester.getTopLeft(name);
    await tester.tap(find.text('Nährwerte anpassen'));
    await tester.pumpAndSettle();
    expect(find.text('78 kcal'), findsNothing);
    expect(tester.getTopLeft(name), initialTop);
    expect(tester.getSize(find.byType(Dialog)).width, greaterThan(350));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(name), initialTop);
    expect(name.hitTestable(), findsOneWidget);
    expect(find.text('Speichern').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
