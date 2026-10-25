import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/nutrition_label_draft.dart';
import 'package:sophis/services/food_intake_controller.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/ui/screens/label_review_screen.dart';

import '../helpers/test_services.dart';

FoodItem _product(NutritionLabelResult label) => FoodItem(
      id: 'scan-1',
      name: label.productName ?? 'Scanned product',
      category: 'custom',
      caloriesPer100g: label.caloriesPer100g,
      proteinPer100g: label.proteinPer100g,
      carbsPer100g: label.carbsPer100g,
      fatPer100g: label.fatPer100g,
      fiberPer100g: label.fiberPer100g,
      nutritionUnit: label.nutritionUnit,
    );

void main() {
  group('LabelReviewScreen', () {
    testWidgets('logged a complete scan in one tap and kept the product',
        (tester) async {
      final nutrition =
          (await tester.runAsync(() => createLoadedNutritionProvider()))!;
      final settings = await createWidgetTestSettingsProvider(tester);
      LabelReviewOutcome? outcome;
      NutritionLabelResult? confirmed;
      await pumpTestApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              outcome = await Navigator.push<LabelReviewOutcome>(
                context,
                MaterialPageRoute(
                  builder: (_) => LabelReviewScreen(
                    draft: const NutritionLabelDraft(
                      productName: 'Skyr',
                      caloriesPer100: 62,
                      proteinPer100: 11,
                      carbsPer100: 4,
                      fatPer100: 0.2,
                    ),
                    meal: 'breakfast',
                    buildProduct: _product,
                    onLogged: (label) async => confirmed = label,
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
        nutritionProvider: nutrition,
        settingsProvider: settings,
        foodIntakeController: FoodIntakeController(nutrition),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      final add = find.textContaining('100 g · 62 kcal');
      expect(add, findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(add);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(outcome, LabelReviewOutcome.logged);
      expect(confirmed?.proteinPer100g, 11);
      expect(
        nutrition.customFoods.where((f) => f.name == 'Skyr'),
        hasLength(1),
      );
      expect(
        nutrition.entries.where((e) => e.sourceFoodId == 'scan-1'),
        hasLength(1),
      );
    });

    testWidgets('asked only for the missing values before logging',
        (tester) async {
      final nutrition =
          (await tester.runAsync(() => createLoadedNutritionProvider()))!;
      final settings = await createWidgetTestSettingsProvider(tester);
      await pumpTestApp(
        tester,
        const LabelReviewScreen(
          draft: NutritionLabelDraft(
            caloriesPer100: 64,
            proteinPer100: 5,
            carbsPer100: 7.2,
          ),
          meal: 'snack',
          needsReview: true,
          buildProduct: _product,
        ),
        nutritionProvider: nutrition,
        settingsProvider: settings,
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Some values may be uncertain. Check the fields before adding.',
        ),
        findsOneWidget,
      );
      expect(find.text('Required'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);

      await tester.enterText(find.byType(TextField).at(4), '1,7');
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(find.textContaining('100 g · 64 kcal'), findsOneWidget);
    });
  });
}
