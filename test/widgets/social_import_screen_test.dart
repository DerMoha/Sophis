import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sophis/models/custom_meal_type.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/models/shareable_meal.dart';
import 'package:sophis/models/social/social_snapshot.dart';
import 'package:sophis/providers/social_provider.dart';
import 'package:sophis/services/social/social_repository.dart';
import 'package:sophis/ui/screens/social/social_import_screen.dart';

import '../helpers/test_services.dart';

void main() {
  SocialPost post(SocialSnapshot snapshot) => SocialPost(
        id: 'post',
        authorId: 'author',
        snapshot: snapshot,
        nutritionVisible: snapshot.nutritionAvailable,
        revision: 1,
        isRecipe: true,
        publishedAt: DateTime(2026),
      );

  Future<void> fill(WidgetTester tester, String label, String value) async {
    final field = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
  }

  Future<void> submit(WidgetTester tester, String text) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('logged only selected partner items and rejected empty selection',
      (tester) async {
    final nutrition = await createLoadedWidgetNutritionProvider(tester);
    final settings = await createWidgetTestSettingsProvider(tester);
    final social = SocialProvider(configured: false);
    addTearDown(social.dispose);
    await pumpTestApp(
      tester,
      ChangeNotifierProvider.value(
        value: social,
        child: SocialImportScreen(
          post: post(
            SocialSnapshot(
              title: 'Partner day',
              servings: 1,
              items: const [
                SharedFoodItem(
                  name: 'Rice',
                  calories: 200,
                  protein: 4,
                  carbs: 40,
                  fat: 1,
                ),
                SharedFoodItem(
                  name: 'Beans',
                  calories: 100,
                  protein: 8,
                  carbs: 15,
                  fat: 1,
                ),
              ],
            ),
          ),
        ),
      ),
      nutritionProvider: nutrition,
      settingsProvider: settings,
    );
    Future<void> toggle(String name) async {
      final tile = find.widgetWithText(CheckboxListTile, name);
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }

    await toggle('Rice');
    await toggle('Beans');
    await submit(tester, 'Add my portion');
    expect(find.text('Choose at least one item to log.'), findsOneWidget);
    expect((await nutrition.store.snapshot()).value.foodEntries, isEmpty);
    await toggle('Beans');
    await submit(tester, 'Add my portion');
    final entry = (await nutrition.store.snapshot()).value.foodEntries.single;
    expect(entry.name, 'Beans');
    expect(entry.calories, 100);
  });

  testWidgets(
      'required hidden nutrition and saved only the chosen portion in a custom meal',
      (tester) async {
    final nutrition = await createLoadedWidgetNutritionProvider(tester);
    final settings = await createWidgetTestSettingsProvider(tester);
    await settings
        .setMealTypes([const CustomMealType(id: 'brunch', name: 'Brunch')]);
    final social = SocialProvider(configured: false);
    addTearDown(social.dispose);
    final source = SocialSnapshot(
      title: 'Dinner',
      servings: 2,
      nutritionAvailable: false,
      items: const [
        SharedFoodItem(
          name: 'Rice',
          calories: 0,
          protein: 0,
          carbs: 0,
          fat: 0,
          portionGrams: 300,
          portionUnit: NutritionUnit.gram,
        ),
      ],
    );
    await pumpTestApp(
      tester,
      ChangeNotifierProvider.value(
        value: social,
        child: SocialImportScreen(post: post(source)),
      ),
      nutritionProvider: nutrition,
      settingsProvider: settings,
    );
    await submit(tester, 'Add my portion');
    expect((await nutrition.store.snapshot()).value.foodEntries, isEmpty);
    expect(find.text('Enter a non-negative amount'), findsWidgets);
    await fill(tester, 'Calories (kcal)', '400');
    await fill(tester, 'Protein (g)', '8');
    await fill(tester, 'Carbs (g)', '88');
    await fill(tester, 'Fat (g)', '1');
    await fill(tester, 'Fiber (g)', '2');
    await fill(tester, 'Your servings', '0.5');
    await submit(tester, 'Add my portion');
    final entry = (await nutrition.store.snapshot()).value.foodEntries.single;
    expect(entry.calories, 100);
    expect(entry.portionAmount, 75);
    expect(entry.meal, 'brunch');
    expect(entry.sourceFoodId, isNull);
  });

  testWidgets(
      'required a measured recipe weight instead of treating milliliters as grams',
      (tester) async {
    final nutrition = await createLoadedWidgetNutritionProvider(tester);
    final settings = await createWidgetTestSettingsProvider(tester);
    final social = SocialProvider(configured: false);
    addTearDown(social.dispose);
    final source = SocialSnapshot(
      title: 'Sauce',
      servings: 2,
      items: const [
        SharedFoodItem(
          name: 'Sauce',
          calories: 100,
          protein: 1,
          carbs: 5,
          fat: 8,
          portionGrams: 200,
          portionUnit: NutritionUnit.milliliter,
        ),
      ],
    );
    await pumpTestApp(
      tester,
      ChangeNotifierProvider.value(
        value: social,
        child: SocialImportScreen(post: post(source), saveRecipe: true),
      ),
      nutritionProvider: nutrition,
      settingsProvider: settings,
    );
    await submit(tester, 'Save my recipe copy');
    expect((await nutrition.store.snapshot()).value.recipes, isEmpty);
    expect(find.text('Enter an amount greater than zero'), findsOneWidget);
    await fill(tester, 'Ingredient weight for the whole recipe (g)', '150');
    await submit(tester, 'Save my recipe copy');
    final recipe = (await nutrition.store.snapshot()).value.recipes.single;
    expect(recipe.ingredients.single.amountGrams, 150);
    expect(recipe.ingredients.single.calories, 100);
    expect(recipe.servings, 2);
  });
}
