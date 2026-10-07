import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:sophis/main.dart' as app;
import 'package:sophis/models/recipe.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/social_provider.dart';
import 'package:sophis/services/nutrition/nutrition_store.dart';
import 'package:sophis/services/social/social_runtime.dart';
import 'package:sophis/ui/screens/social/people_screen.dart';
import 'package:sophis/ui/screens/recipes_screen.dart';
import 'package:sophis/ui/screens/food_diary_screen.dart';
import 'package:sophis/ui/components/organic_components.dart';
import 'package:sophis/ui/screens/social/social_connections_screen.dart';

import 'social_screen_capture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('dexterous.com/flutter/local_notifications'),
    (call) async => call.method == 'initialize' ? true : null,
  );

  Future<void> waitFor(WidgetTester tester, bool Function() condition) async {
    for (var attempt = 0; attempt < 200 && !condition(); attempt++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(condition(), isTrue);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pumpAndSettle();
    await waitFor(tester, () => finder.hitTestable().evaluate().isNotEmpty);
    await tester.tap(finder);
  }

  testWidgets(
      'shared a recipe between approved accounts and kept imported copies after owner edits and deletion',
      (tester) async {
    expect(SocialRuntime.configuration()?.options.projectId, 'demo-sophis');
    app.main();
    await waitFor(tester, () => app.navigatorKey.currentContext != null);
    final navigator = app.navigatorKey.currentState!;
    final nutrition =
        app.navigatorKey.currentContext!.read<NutritionProvider>();
    final original = (await nutrition.store.snapshot()).value;
    final marker = DateTime.now().microsecondsSinceEpoch.toString();
    final recipeName = 'Simulator dinner $marker';
    final ingredientName = 'Simulator rice $marker';
    final sourceId = 'simulator_source_$marker';
    final authorEmail = 'author-$marker@example.invalid';
    final recipientEmail = 'recipient-$marker@example.invalid';
    const password = 'SophisSimulator123!';
    navigator
        .push(MaterialPageRoute<void>(builder: (_) => const PeopleScreen()));
    await waitFor(
      tester,
      () => app.navigatorKey.currentContext!.read<SocialProvider>().ready,
    );
    final social = app.navigatorKey.currentContext!.read<SocialProvider>();
    try {
      await social.signOut();
      await social.authenticate(authorEmail, password, create: true);
      await social.saveProfile('Author $marker');
      expect(
        social.profile?.displayName,
        'Author $marker',
        reason: social.message,
      );
      final authorId = social.accountId!;
      expect(
        (await nutrition.store.commit(
          SaveRecipe(
            Recipe(
              id: sourceId,
              name: recipeName,
              servings: 2,
              createdAt: DateTime.now(),
              ingredients: [
                RecipeIngredient(
                  id: 'private-$marker',
                  name: ingredientName,
                  amountGrams: 300,
                  calories: 400,
                  protein: 8,
                  carbs: 88,
                  fat: 1,
                ),
              ],
            ),
          ),
        ))
            .isSuccess,
        isTrue,
      );
      await nutrition.reloadAll();
      await tap(
        tester,
        find.text('Share a meal or recipe'),
      );
      await waitFor(tester, () => find.text(recipeName).evaluate().isNotEmpty);
      await tap(tester, find.widgetWithText(ListTile, recipeName));
      await waitFor(
        tester,
        () => find.text('Publish to followers').evaluate().isNotEmpty,
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Made for dinner',
      );
      await tap(
        tester,
        find.widgetWithText(FilledButton, 'Publish to followers'),
      );
      await waitFor(
        tester,
        () => social.posts.any((post) => post.snapshot.title == recipeName),
      );
      final published =
          social.posts.singleWhere((post) => post.snapshot.title == recipeName);
      navigator.pop(); // chooser -> People
      await tester.pumpAndSettle();
      navigator
          .push(MaterialPageRoute<void>(builder: (_) => const RecipesScreen()));
      await tester.pumpAndSettle();
      final recipeTile = find.ancestor(
        of: find.text(recipeName),
        matching: find.byType(ListTile),
      );
      await tap(
        tester,
        find.descendant(
          of: recipeTile,
          matching:
              find.byWidgetPredicate((widget) => widget is PopupMenuButton),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.text('Share with followers'));
      await waitFor(
        tester,
        () => find.text('Publish to followers').evaluate().isNotEmpty,
      );
      navigator.pop(); // preview -> recipes
      await tester.pumpAndSettle();
      navigator.pop(); // recipes -> People
      await tester.pumpAndSettle();
      await captureSocialScreen(binding, tester, 'sharing-published-post');
      final invitation =
          (await social.runtime!.accounts.invite('follow')).value;

      await social.signOut();
      await social.authenticate(recipientEmail, password, create: true);
      await social.saveProfile('Recipient $marker');
      expect(social.posts, isEmpty);
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              SocialConnectionsScreen(invitationToken: invitation.token),
        ),
      );
      await waitFor(
        tester,
        () => find.text('Preview invitation').evaluate().isNotEmpty,
      );
      await tap(tester, find.widgetWithText(TextButton, 'Preview invitation'));
      await waitFor(
        tester,
        () => find.text('Send request').evaluate().isNotEmpty,
      );
      expect(find.text('Author $marker'), findsOneWidget);
      await tap(tester, find.widgetWithText(FilledButton, 'Send request'));
      await waitFor(
        tester,
        () => find
            .text('Request sent. Waiting for approval.')
            .evaluate()
            .isNotEmpty,
      );
      expect(
        (await social.runtime!.repository.fetchFeed()).value.posts,
        isEmpty,
      );
      navigator.pop();
      await social.signOut();
      await social.authenticate(authorEmail, password, create: false);
      await tester.pumpAndSettle();
      await tap(tester, find.byTooltip('Connections'));
      await waitFor(tester, () => find.text('Approve').evaluate().isNotEmpty);
      await tap(tester, find.widgetWithText(TextButton, 'Approve'));
      await waitFor(tester, () => find.text('Approved').evaluate().isNotEmpty);
      navigator.pop();

      await social.signOut();
      await social.authenticate(recipientEmail, password, create: false);
      expect(social.posts.single.id, published.id);
      expect(social.posts.single.authorId, authorId);
      await tester.pumpAndSettle();
      await tap(tester, find.byTooltip('React'));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Looks delicious'));
      await waitFor(
        tester,
        () => find.text('Reaction saved to send.').evaluate().isNotEmpty,
      );
      await waitFor(tester, () => !social.busy);
      expect(
        await social.runtime!.store.nextCommand(
          await social.runtime!.store.session(),
          DateTime.now(),
        ),
        isNull,
      );

      await tap(tester, find.widgetWithText(TextButton, 'Add to diary'));
      await waitFor(
        tester,
        () => find.text('Your servings').evaluate().isNotEmpty,
      );
      await captureSocialScreen(binding, tester, 'sharing-diary-import');
      await tester.enterText(find.byType(TextFormField).first, '0.5');
      await tap(tester, find.widgetWithText(FilledButton, 'Add my portion'));
      await waitFor(
        tester,
        () => nutrition
            .getTodayEntries()
            .any((entry) => entry.name == ingredientName),
      );
      final copy = (await nutrition.store.snapshot())
          .value
          .foodEntries
          .singleWhere((entry) => entry.name == ingredientName);
      expect(copy.calories, 100);
      expect(copy.portionAmount, 75);
      expect(copy.sourceFoodId, isNull);
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const FoodDiaryScreen()),
      );
      await tester.pumpAndSettle();
      final mealCard = find
          .ancestor(
            of: find.text(ingredientName),
            matching: find.byType(MealCard),
          )
          .first;
      await tap(
        tester,
        find.descendant(
          of: mealCard,
          matching: find.byTooltip('Share with followers'),
        ),
      );
      await waitFor(
        tester,
        () => find.text('Publish to followers').evaluate().isNotEmpty,
      );
      navigator.pop(); // preview -> diary; no diary content is published
      await tester.pumpAndSettle();
      navigator.pop(); // diary -> People
      await tester.pumpAndSettle();

      await tap(tester, find.widgetWithText(TextButton, 'Save recipe'));
      await waitFor(
        tester,
        () => find.text('Save my recipe copy').evaluate().isNotEmpty,
      );
      await tap(
        tester,
        find.widgetWithText(FilledButton, 'Save my recipe copy'),
      );
      await waitFor(
        tester,
        () => nutrition.recipes.any(
          (recipe) =>
              recipe.id.startsWith('social_recipe_') &&
              recipe.name == recipeName,
        ),
      );
      final recipeCopy = nutrition.recipes.singleWhere(
        (recipe) =>
            recipe.id.startsWith('social_recipe_') && recipe.name == recipeName,
      );
      expect(recipeCopy.id, isNot(sourceId));

      await social.signOut();
      await social.authenticate(authorEmail, password, create: false);
      await tester.pumpAndSettle();
      await tap(tester, find.widgetWithText(TextButton, 'Edit post'));
      await waitFor(
        tester,
        () => find.text('Save post changes').evaluate().isNotEmpty,
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'Changed dinner $marker',
      );
      await tap(tester, find.widgetWithText(FilledButton, 'Save post changes'));
      await waitFor(
        tester,
        () => social.posts.single.snapshot.title == 'Changed dinner $marker',
      );
      expect(social.posts.single.revision, 2);
      await tap(tester, find.widgetWithText(TextButton, 'Delete post'));
      await tester.pumpAndSettle();
      await tap(tester, find.widgetWithText(FilledButton, 'Delete post'));
      await waitFor(tester, () => !social.busy && social.posts.isEmpty);
      await social.signOut();
      await social.authenticate(recipientEmail, password, create: false);
      expect(social.posts, isEmpty);
      final retained = (await nutrition.store.snapshot()).value;
      expect(
        retained.foodEntries
            .singleWhere((entry) => entry.id == copy.id)
            .toJson(),
        copy.toJson(),
      );
      expect(
        retained.recipes
            .singleWhere((recipe) => recipe.id == recipeCopy.id)
            .toJson(),
        recipeCopy.toJson(),
      );
    } finally {
      await social.signOut();
      final current = (await nutrition.store.snapshot()).value;
      // Remove only uniquely named synthetic copies created by this test.
      for (final entry in current.foodEntries.where(
        (entry) =>
            entry.name == ingredientName &&
            entry.id.startsWith('social_import_'),
      )) {
        await nutrition.store.commit(DeleteFoodEntry(entry.id));
      }
      for (final recipe in current.recipes.where(
        (recipe) =>
            recipe.id == sourceId ||
            recipe.name == recipeName && recipe.id.startsWith('social_recipe_'),
      )) {
        await nutrition.store.commit(DeleteRecipe(recipe.id));
      }
      await nutrition.reloadAll();
      final after = (await nutrition.store.snapshot()).value;
      expect(
        after.foodEntries.map((entry) => entry.toJson()).toList(),
        original.foodEntries.map((entry) => entry.toJson()).toList(),
      );
      expect(
        after.recipes.map((recipe) => recipe.toJson()).toList(),
        original.recipes.map((recipe) => recipe.toJson()).toList(),
      );
    }
  });
}
