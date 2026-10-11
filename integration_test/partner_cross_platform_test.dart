import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sophis/main.dart' as app;
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/social_provider.dart';
import 'package:sophis/services/nutrition/nutrition_store.dart';
import 'package:sophis/services/social/social_runtime.dart';
import 'package:sophis/ui/screens/social/people_screen.dart';
import 'package:sophis/ui/screens/social/social_partners_screen.dart';

/// Opt-in, two-device production check. Run author on Android and recipient on
/// iOS together, with the local relay in tool/partner_test_coordinator.py.
/// Each install retains its own account and diary throughout the exchange.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('dexterous.com/flutter/local_notifications'),
    (call) async => call.method == 'initialize' ? true : null,
  );
  const role = String.fromEnvironment('PARTNER_TEST_ROLE');
  const run = String.fromEnvironment('PARTNER_TEST_RUN');
  const host =
      String.fromEnvironment('PARTNER_TEST_HOST', defaultValue: '127.0.0.1');
  const enabled = bool.fromEnvironment('PARTNER_TEST_PRODUCTION');

  testWidgets(
    'exchanged partner days between separate Android and iOS installs',
    (tester) async {
      expect(enabled, isTrue);
      expect(['author', 'recipient'], contains(role));
      expect(run, isNotEmpty);
      expect(SocialRuntime.configuration()?.options.projectId, 'sophis-d2953');
      final relay = http.Client();
      Future<void> signal(
        String event, [
        Map<String, dynamic> data = const {},
      ]) async {
        final response = await tester.runAsync(
          () => relay
              .post(
                Uri.parse('http://$host:18765/$run/$event'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(data),
              )
              .timeout(const Duration(seconds: 10)),
        );
        expect(response?.statusCode, 200);
        debugPrint('PARTNER CROSS PLATFORM: $role $event');
      }

      Future<Map<String, dynamic>> awaitEvent(String event) async {
        final deadline = DateTime.now().add(const Duration(minutes: 12));
        while (DateTime.now().isBefore(deadline)) {
          final aborted = await tester.runAsync(
            () => relay.get(
              Uri.parse('http://$host:18765/$run/aborted'),
            ),
          );
          if (aborted?.statusCode == 200) {
            throw TestFailure('The other platform failed its test.');
          }
          final response = await tester.runAsync(
            () => relay
                .get(
                  Uri.parse('http://$host:18765/$run/$event'),
                )
                .timeout(const Duration(seconds: 10)),
          );
          if (response?.statusCode == 200) {
            return jsonDecode(response!.body) as Map<String, dynamic>;
          }
          await tester.pump(const Duration(milliseconds: 300));
          await tester
              .runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
        }
        throw TestFailure('Timed out waiting for other platform: $event');
      }

      Future<void> waitFor(
        bool Function() condition,
        String description,
      ) async {
        for (var i = 0; i < 300 && !condition(); i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(condition(), isTrue, reason: description);
      }

      Future<void> tap(Finder finder) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      app.main();
      await tester.pumpAndSettle();
      await waitFor(
        () => app.navigatorKey.currentContext != null,
        'App startup',
      );
      final navigator = app.navigatorKey.currentState!;
      final nutrition =
          app.navigatorKey.currentContext!.read<NutritionProvider>();
      final directory = await getApplicationSupportDirectory();
      final backup =
          File('${directory.path}/partner-cross-platform-backup.json');
      Future<void> restoreFixtureDiary() async {
        if (!backup.existsSync()) return;
        final saved =
            jsonDecode(await backup.readAsString()) as Map<String, dynamic>;
        for (final id in (saved['fixtureIds'] as List).cast<String>()) {
          await nutrition.store.commit(DeleteFoodEntry(id));
        }
        await nutrition.store.commit(
          SaveGoals(
            saved['goals'] == null
                ? null
                : NutritionGoals.fromJson(
                    saved['goals'] as Map<String, dynamic>,
                  ),
          ),
        );
        await nutrition.reloadAll();
        await backup.delete();
      }

      await restoreFixtureDiary();
      // Recover the known fixture left by the workstation sleeping before the
      // first version of this test had a durable recovery checkpoint.
      await nutrition.store
          .commit(const DeleteFoodEntry('cross_platform_20261008d_$role'));
      await nutrition.reloadAll();
      final original = (await nutrition.store.snapshot()).value;
      navigator
          .push(MaterialPageRoute<void>(builder: (_) => const PeopleScreen()));
      await waitFor(
        () => app.navigatorKey.currentContext!.read<SocialProvider>().ready,
        'Firebase initialization',
      );
      final social = app.navigatorKey.currentContext!.read<SocialProvider>();
      String? connectionId;
      String? importedId;
      const sourceId = 'cross_platform_${run}_$role';
      const pausedId = '${sourceId}_paused';
      final fixtureIds = <String>[sourceId, pausedId];
      Future<void> checkpoint() => backup
          .writeAsString(
            jsonEncode({
              'goals': original.goals?.toJson(),
              'fixtureIds': fixtureIds,
            }),
          )
          .then((_) {});
      await checkpoint();
      Future<void> cleanupFixtureAccount() async {
        final user = social.runtime?.auth.auth.currentUser;
        final fixture = RegExp(
          r'^sophis-cross-(author|recipient)-([A-Za-z0-9_-]+)@example\.invalid$',
        ).firstMatch(user?.email ?? '');
        if (fixture == null) return;
        await social.refreshPartners();
        for (final connection in social.partners) {
          await social.runtime!.partners
              .request('disconnectPartner', {'connectionId': connection.id});
        }
        await user!.reauthenticateWithCredential(
          EmailAuthProvider.credential(
            email: user.email!,
            password: 'CrossPlatform-${fixture.group(2)}-Aa!7',
          ),
        );
        await user.delete();
        await social.signOut();
      }

      await cleanupFixtureAccount();
      Future<void> openDetail() async {
        navigator.popUntil((route) => route.isFirst);
        await tester.pumpAndSettle();
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                SocialPartnerDetailScreen(connectionId: connectionId!),
          ),
        );
        await waitFor(
          () =>
              find
                  .byKey(const ValueKey('partner_today'))
                  .evaluate()
                  .isNotEmpty &&
              find
                  .byWidgetPredicate(
                    (widget) =>
                        widget is LinearProgressIndicator &&
                        widget.value == null,
                  )
                  .evaluate()
                  .isEmpty,
          'Partner day loaded: ${social.message}',
        );
        await tester.pumpAndSettle();
        debugPrint(
          'PARTNER TEST $role day: ${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).join(' | ')}',
        );
      }

      Future<void> publish(double calories, double target) async {
        await nutrition.store.commit(
          SaveGoals(
            NutritionGoals(
              calories: target,
              protein: 130,
              carbs: 260,
              fat: 75,
            ),
          ),
        );
        await nutrition.store.commit(
          SaveFoodEntry(
            FoodEntry(
              id: sourceId,
              name: '$role test rice',
              calories: calories,
              protein: 20,
              carbs: 50,
              fat: 10,
              timestamp: DateTime.now(),
              meal: 'dinner',
            ),
          ),
        );
        await nutrition.reloadAll();
        await social.syncPartnerChanges();
        expect(social.message, isNull, reason: 'Publish $role');
        debugPrint(
          'PARTNER TEST synthetic publish: now=${DateTime.now().toUtc()} settings=${social.partners.single.ownSettings} goals=${nutrition.goals?.calories}',
        );
      }

      try {
        await social.signOut();
        await tester.pumpAndSettle();
        await tap(find.widgetWithText(TextButton, 'Create an account'));
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'),
          'sophis-cross-$role-$run@example.invalid',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'),
          'CrossPlatform-$run-Aa!7',
        );
        await tap(find.widgetWithText(FilledButton, 'Create account'));
        await waitFor(
          () => social.needsProfile,
          'Created native account: ${social.message}',
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Display name'),
          role == 'author' ? 'Android partner (test)' : 'iOS partner (test)',
        );
        await tap(find.text('Save profile'));
        await waitFor(
          () => social.profile != null,
          'Saved profile: ${social.message}',
        );
        await signal('$role-account-ready');
        if (role == 'author') {
          final invitation = await social.runtime!.accounts.invite('partner');
          expect(invitation.isSuccess, isTrue);
          await signal('invitation', {'token': invitation.value.token});
          await awaitEvent('requested');
          await social.refreshPartners();
          connectionId = social.partners.single.id;
          navigator.popUntil((route) => route.isFirst);
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => const SocialPartnersScreen(),
            ),
          );
          await waitFor(
            () => find.text('Accept partner').evaluate().isNotEmpty,
            'Pending partner visible',
          );
          await tap(find.text('Accept partner'));
          await waitFor(
            () => social.partners.single.accepted,
            'Accepted connection',
          );
          await openDetail();
          await publish(400, 2200);
          await signal('author-shared', {'connectionId': connectionId});
          await awaitEvent('recipient-shared');
          await openDetail();
          expect(find.text('Calories: 300 / 1800 kcal'), findsOneWidget);
          expect(find.text('Protein: 20 / 130 g'), findsOneWidget);
          await signal('android-viewed-ios');
          await awaitEvent('ios-imported');
          await openDetail();
          await nutrition.store.commit(
            SaveFoodEntry(
              FoodEntry(
                id: pausedId,
                name: 'Additional test food',
                calories: 999,
                protein: 1,
                carbs: 1,
                fat: 1,
                timestamp: DateTime.now(),
                meal: 'snacks',
              ),
            ),
          );
          await nutrition.store.commit(
            SaveGoals(
              NutritionGoals(
                calories: 2500,
                protein: 150,
                carbs: 300,
                fat: 80,
              ),
            ),
          );
          await nutrition.reloadAll();
          await social.syncPartnerChanges();
          await signal('author-updated');
          await awaitEvent('ios-verified-update');
          expect(
            (await social.runtime!.partners.request(
              'disconnectPartner',
              {'connectionId': connectionId},
            ))
                .isSuccess,
            isTrue,
          );
          await signal('disconnected');
          await awaitEvent('ios-verified-disconnect');
        } else {
          final invitation = await awaitEvent('invitation');
          final token = invitation['token'] as String;
          final preview = await social.runtime!.accounts.preview(token);
          expect(preview.isSuccess, isTrue);
          expect(
            (await social.runtime!.accounts.request(preview.value, token))
                .isSuccess,
            isTrue,
          );
          await signal('requested');
          final shared = await awaitEvent('author-shared');
          connectionId = shared['connectionId'] as String;
          await social.refreshPartners();
          await openDetail();
          expect(find.text('Calories: 400 / 2200 kcal'), findsOneWidget);
          expect(find.text('Protein: 20 / 130 g'), findsOneWidget);
          await publish(300, 1800);
          await signal('recipient-shared');
          await awaitEvent('android-viewed-ios');
          await openDetail();
          await tester.scrollUntilVisible(
            find.text('author test rice'),
            300,
            scrollable: find
                .descendant(
                  of: find.byType(SocialPartnerDetailScreen),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tap(find.text('Choose items from this day'));
          await tester.enterText(
            find.widgetWithText(TextFormField, 'Your servings'),
            '0.5',
          );
          final before = (await nutrition.store.snapshot())
              .value
              .foodEntries
              .map((e) => e.id)
              .toSet();
          await tap(find.text('Add my portion'));
          await waitFor(
            () => find.text('Add my portion').evaluate().isEmpty,
            'Imported portion',
          );
          final imported = (await nutrition.store.snapshot())
              .value
              .foodEntries
              .where((e) => !before.contains(e.id))
              .single;
          importedId = imported.id;
          fixtureIds.add(imported.id);
          await checkpoint();
          expect(imported.name, 'author test rice');
          expect(imported.calories, 200);
          expect(
            (await nutrition.store.snapshot())
                .value
                .foodEntries
                .any((e) => e.id == sourceId),
            isTrue,
          );
          await signal('ios-imported');
          await awaitEvent('author-updated');
          await openDetail();
          expect(find.text('Calories: 1399 / 2500 kcal'), findsOneWidget);
          expect(find.byType(Switch), findsNothing);
          await signal('ios-verified-update');
          await awaitEvent('disconnected');
          await social.refreshPartners();
          expect(social.partners, isEmpty);
          expect(
            (await nutrition.store.snapshot())
                .value
                .foodEntries
                .singleWhere((e) => e.id == importedId)
                .calories,
            200,
          );
          await signal('ios-verified-disconnect');
        }
        await signal('$role-passed');
      } catch (_) {
        await signal('aborted');
        rethrow;
      } finally {
        try {
          await cleanupFixtureAccount();
        } finally {
          await social.signOut();
          await restoreFixtureDiary();
          relay.close();
        }
        final restored = (await nutrition.store.snapshot()).value;
        expect(
          restored.foodEntries.map((e) => e.toJson()).toList(),
          original.foodEntries.map((e) => e.toJson()).toList(),
        );
        expect(restored.goals?.toJson(), original.goals?.toJson());
        relay.close();
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 25)),
  );
}
