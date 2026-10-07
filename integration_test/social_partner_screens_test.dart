import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:sophis/main.dart' as app;
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/social_provider.dart';
import 'package:sophis/services/nutrition/nutrition_store.dart';
import 'package:sophis/services/social/social_runtime.dart';
import 'package:sophis/ui/components/settings/settings_tiles.dart';
import 'package:sophis/ui/screens/social/people_screen.dart';
import 'package:sophis/ui/screens/social/social_partners_screen.dart';

import 'social_screen_capture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => call.method == 'initialize' ? true : null,);
  Future<void> waitFor(WidgetTester tester, bool Function() condition) async {
    for (var i = 0; i < 300 && !condition(); i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(condition(), isTrue);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'shared independent partner goals and eligible daily progress with native consent screens',
      (tester) async {
    expect(SocialRuntime.configuration()?.options.projectId, 'demo-sophis');
    app.main();
    await tester.pumpAndSettle();
    await waitFor(tester, () => app.navigatorKey.currentContext != null);
    final navigator = app.navigatorKey.currentState!;
    final nutrition =
        app.navigatorKey.currentContext!.read<NutritionProvider>();
    final original = (await nutrition.store.snapshot()).value;
    final marker = DateTime.now().microsecondsSinceEpoch.toString();
    final authorEmail = 'partner-author-$marker@example.invalid';
    final recipientEmail = 'partner-recipient-$marker@example.invalid';
    const password = 'SophisSimulator123!';
    String? connectionId;
    navigator
        .push(MaterialPageRoute<void>(builder: (_) => const PeopleScreen()));
    await waitFor(tester,
        () => app.navigatorKey.currentContext!.read<SocialProvider>().ready,);
    final social = app.navigatorKey.currentContext!.read<SocialProvider>();
    Future<void> switchAccount(String email) async {
      await social.signOut();
      await social.authenticate(email, password, create: false);
      expect(social.profile, isNotNull, reason: social.message);
    }

    Future<void> openDetail() async {
      navigator.popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();
      navigator.push(MaterialPageRoute<void>(
          builder: (_) =>
              SocialPartnerDetailScreen(connectionId: connectionId!),),);
      await waitFor(
          tester,
          () =>
              find.text('Share nutrition goals').evaluate().isNotEmpty &&
              find.byWidgetPredicate((widget) => widget is LinearProgressIndicator && widget.value == null).evaluate().isEmpty,);
    }

    Future<void> change(String title, String field, bool value) async {
      final tile = find.widgetWithText(SwitchTile, title);
      await tap(
          tester, find.descendant(of: tile, matching: find.byType(Switch)),);
      await waitFor(
          tester, () => social.partners.single.ownSettings[field] == value,);
      await waitFor(
          tester,
          () =>
              find.byWidgetPredicate((widget) => widget is LinearProgressIndicator && widget.value == null).evaluate().isEmpty ||
              find.text('Share nutrition goals').evaluate().isEmpty,);
      await tester.pumpAndSettle();
    }

    FoodEntry entry(String suffix, double calories) => FoodEntry(
        id: 'partner_${marker}_$suffix',
        name: 'Rice bowl $suffix $marker',
        calories: calories,
        protein: 20,
        carbs: 50,
        fat: 10,
        timestamp: DateTime.now(),
        meal: 'dinner',);
    try {
      await social.signOut();
      await social.authenticate(authorEmail, password, create: true);
      await social.saveProfile('Jamie');
      expect(social.profile?.displayName, 'Jamie', reason: social.message);
      final invite = (await social.runtime!.accounts.invite('partner')).value;
      await social.signOut();
      await social.authenticate(recipientEmail, password, create: true);
      await social.saveProfile('Alex');
      final preview =
          (await social.runtime!.accounts.preview(invite.token)).value;
      expect(
          (await social.runtime!.accounts.request(preview, invite.token))
              .isSuccess,
          isTrue,);
      await switchAccount(authorEmail);
      navigator.push(MaterialPageRoute<void>(
          builder: (_) => const SocialPartnersScreen(),),);
      await waitFor(
          tester, () => find.text('Accept partner').evaluate().isNotEmpty,);
      connectionId = social.partners.single.id;
      await tap(tester, find.text('Accept partner'));
      await waitFor(tester,
          () => find.text('Goals, progress and meals').evaluate().isNotEmpty,);
      await tap(tester, find.text('Goals, progress and meals'));
      await waitFor(tester,
          () => find.text('Share nutrition goals').evaluate().isNotEmpty,);
      await nutrition.store.commit(SaveFoodEntry(entry('historical', 999)));
      await nutrition.store.commit(SaveGoals(
          NutritionGoals(calories: 2200, protein: 130, carbs: 260, fat: 75),),);
      await nutrition.reloadAll();
      await change('Share nutrition goals', 'goals', true);
      await change('Share daily progress', 'summaries', true);
      await change('Share logged meals', 'meals', true);
      await nutrition.store.commit(SaveFoodEntry(entry('shared', 400)));
      await nutrition.reloadAll();
      await social.syncPartnerChanges();
      await switchAccount(recipientEmail);
      await openDetail();
      expect(find.text('Calories: 400 / 2200 kcal'), findsOneWidget, reason: tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).join(' | '));
      expect(find.text('Protein: 20 / 130 g'), findsOneWidget);
      await captureSocialScreen(binding, tester, 'partner-goals-progress');
      await tester.scrollUntilVisible(find.text('Rice bowl shared $marker'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Rice bowl shared $marker'), findsOneWidget);
      expect(find.text('Rice bowl historical $marker'), findsNothing);
      await captureSocialScreen(binding, tester, 'partner-shared-meal');
      await switchAccount(authorEmail);
      await openDetail();
      await change('Pause sharing', 'paused', true);
      await nutrition.store.commit(SaveFoodEntry(entry('paused', 500)));
      await nutrition.store.commit(SaveGoals(
          NutritionGoals(calories: 2500, protein: 150, carbs: 300, fat: 80),),);
      await nutrition.reloadAll();
      await social.syncPartnerChanges();
      await switchAccount(recipientEmail);
      await openDetail();
      expect(find.text('Calories: 400 / 2200 kcal'), findsOneWidget);
      expect(find.text('Rice bowl paused $marker'), findsNothing);
      expect(
          find.text(
              'Partner sharing is paused. Previously shared values are frozen.',),
          findsOneWidget,);
      await switchAccount(authorEmail);
      await openDetail();
      await change('Share nutrition goals', 'goals', false);
      await switchAccount(recipientEmail);
      await openDetail();
      expect(find.text('Your partner has not shared nutrition goals.'),
          findsOneWidget,);
      expect(find.text('Calories: 400 / — kcal'), findsOneWidget);
      expect(
          (await social.runtime!.partners
                  .request('disconnectPartner', {'connectionId': connectionId}))
              .isSuccess,
          isTrue,);
    } finally {
      await social.signOut();
      for (final suffix in ['historical', 'shared', 'paused']) {
        await nutrition.store
            .commit(DeleteFoodEntry('partner_${marker}_$suffix'));
      }
      await nutrition.store.commit(SaveGoals(original.goals));
      await nutrition.reloadAll();
      final after = (await nutrition.store.snapshot()).value;
      expect(after.foodEntries.map((e) => e.toJson()).toList(),
          original.foodEntries.map((e) => e.toJson()).toList(),);
      expect(after.goals?.toJson(), original.goals?.toJson());
    }
  });
}
