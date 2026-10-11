import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sophis/models/social/social_snapshot.dart';
import 'package:sophis/services/nutrition/nutrition_store.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/firestore_partner_client.dart';
import 'package:sophis/services/social/social_account_repository.dart';
import 'package:sophis/services/social/social_callable_client.dart';
import 'package:sophis/services/social/social_local_store.dart';
import 'package:sophis/services/social/social_partner_repository.dart';

import '../../helpers/test_services.dart';

final class _Credentials implements SocialCredentials {
  @override
  final String accountId;
  final String token;
  const _Credentials(this.accountId, this.token);
  @override
  Future<SocialTokens> tokensFor(String uid) async =>
      SocialTokens(accountId: accountId, idToken: token);
}

final class _Person {
  final SocialLocalStore store;
  final FirestorePartnerClient client;
  _Person(this.store, this.client);
  SocialAccountRepository get accounts =>
      SocialAccountRepository(client: client, store: store);
  SocialPartnerRepository get partners => SocialPartnerRepository(client);
  Future<Map<String, dynamic>> call(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final result =
        await client.call((await client.captureSession())!, action, payload);
    expect(
      result.isSuccess,
      isTrue,
      reason:
          '$action: ${result is Failure<Map<String, dynamic>> ? result.message : ''}',
    );
    return result.value as Map<String, dynamic>;
  }

  Future<void> setting(String connectionId, String field, bool value) async {
    final connection = (await partners.connections())
        .value
        .singleWhere((c) => c.id == connectionId);
    final result = await partners.settings(connection, field, value);
    expect(
      result.isSuccess,
      isTrue,
      reason: result is Failure<Map<String, dynamic>> ? result.message : '',
    );
  }
}

void main() {
  final enabled = Platform.environment['SOPHIS_SPARK_EMULATOR_TEST'] == '1';
  test(
    'completed the actual Dart partner transport flow, paginated days, imported selected portions and revoked access',
    () async {
      final firestoreHost = Platform.environment['FIRESTORE_EMULATOR_HOST']!;
      final authHost = Platform.environment['FIREBASE_AUTH_EMULATOR_HOST']!;
      final parts = firestoreHost.split(':');
      final httpClient = http.Client();
      final people = <_Person>[];
      addTearDown(() async {
        for (final p in people) {
          await p.store.close();
        }
        httpClient.close();
      });
      Future<_Person> person(String name) async {
        final marker = DateTime.now().microsecondsSinceEpoch;
        final response = await httpClient.post(
          Uri.http(
            authHost,
            '/identitytoolkit.googleapis.com/v1/accounts:signUp',
            {'key': 'demo-api-key'},
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': '$name-$marker@example.invalid',
            'password': 'EmulatorOnly123!',
            'returnSecureToken': true,
          }),
        );
        expect(response.statusCode, 200);
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        final credentials = _Credentials(
          result['localId'] as String,
          result['idToken'] as String,
        );
        final store = SocialLocalStore(NativeDatabase.memory());
        await store.switchAccount(credentials.accountId);
        final client = FirestorePartnerClient(
          credentials: credentials,
          store: store,
          httpClient: httpClient,
          projectId: 'demo-sophis',
          emulatorHost: parts[0],
          emulatorPort: int.parse(parts[1]),
        );
        final p = _Person(store, client);
        people.add(p);
        expect((await p.accounts.saveProfile(name)).isSuccess, isTrue);
        return p;
      }

      final alice = await person('Alice'),
          bob = await person('Bob'),
          eve = await person('Eve');
      final inviteResult = await alice.accounts.invite('partner');
      expect(
        inviteResult.isSuccess,
        isTrue,
        reason: inviteResult is Failure<SocialInvitation>
            ? inviteResult.message
            : '',
      );
      final invite = inviteResult.value;
      final preview = await bob.accounts.preview(invite.token);
      expect(preview.isSuccess, isTrue);
      expect(
        (await bob.accounts.request(preview.value, invite.token)).isSuccess,
        isTrue,
      );
      final connection = (await alice.partners.connections()).value.single;
      final id = connection.id;
      expect(connection.accepted, isFalse);
      expect(
        (await bob.partners.request('acceptPartner', {'connectionId': id}))
            .isFailure,
        isTrue,
      );
      await alice.call('acceptPartner', {'connectionId': id});
      final settings =
          (await alice.partners.connections()).value.single.ownSettings;
      Map<String, dynamic> payload(
        String source, {
        String date = '2026-10-08',
        int? logged,
      }) =>
          {
            'connectionId': id,
            'sourceMealId': source,
            'sourceRevision': 1,
            'consentRevision': settings['revision'],
            'originallyLoggedAt':
                logged ?? DateTime.now().millisecondsSinceEpoch,
            'changedAt': DateTime.now().millisecondsSinceEpoch,
            'localDate': date,
            'timeZone': 'Europe/Berlin',
            'mealCategory': 'lunch',
            'snapshot': {
              'schemaVersion': 1,
              'title': 'Rice $source',
              'servings': 1,
              'items': [
                {
                  'name': 'Rice $source',
                  'calories': 200.0,
                  'protein': 4.0,
                  'carbs': 44.0,
                  'fat': 1.0,
                  'fiber': 2.0,
                  'portionAmount': 150.0,
                  'portionUnit': 'g',
                }
              ],
            },
          };
      await alice.call('syncPartnerGoals', {
        'connectionId': id,
        'consentRevision': settings['revision'],
        'sourceRevision': 1,
        'goals': {
          'calories': 2000.0,
          'protein': 100.0,
          'carbs': 250.0,
          'fat': 70.0,
        },
        'timeZone': 'Europe/Berlin',
      });
      for (var i = 0; i < 25; i++) {
        final p = payload('meal$i');
        await alice.call('syncPartnerMeal', p);
        await alice.call(
          'syncPartnerContribution',
          {...p, 'calories': 200.0, 'protein': 4.0, 'carbs': 44.0, 'fat': 1.0},
        );
      }
      await alice.call(
        'syncPartnerMeal',
        payload('different-day', date: '2026-10-07'),
      );
      await alice.call('syncPartnerMeal', payload('backfill', logged: 0));
      final day = {
        'connectionId': id,
        'localDate': '2026-10-08',
        'timeZone': 'Europe/Berlin',
      };
      final page = await bob.call('partnerMeals', day);
      expect(page['meals'], hasLength(20));
      expect(page['cursor'], isNotNull);
      final page2 =
          await bob.call('partnerMeals', {...day, 'cursor': page['cursor']});
      expect(page2['meals'], hasLength(6));
      expect(page2['cursor'], isNull);
      final meals = [...(page['meals'] as List), ...(page2['meals'] as List)]
          .cast<Map<String, dynamic>>();
      expect(meals.map((m) => m['id']).toSet(), hasLength(26));
      expect(
        (await bob.call('partnerGoals', {'connectionId': id}))['goals'],
        hasLength(1),
      );
      final summary = await bob.call('partnerSummaries', day);
      expect(
          ((summary['summaries'] as List).single as Map)['calories'], 5000.0,);
      expect(
          (await eve.partners.request('partnerMeals', day)).isFailure, isTrue,);
      // Import one selected shared item at half the author's portion, retry safely.
      final local =
          NutritionStore(createTestDatabase(), await createTestStorage());
      addTearDown(local.close);
      final shared = SocialSnapshot.fromJson(
        meals.first['snapshot'] as Map<String, dynamic>,
        nutritionVisible: true,
      );
      final command = ImportSocialMeal(
        operationId: 'spark-copy',
        snapshot: shared,
        selectedServings: 0.5,
        timestamp: DateTime(2026, 10, 9),
        meal: 'dinner',
      );
      expect((await local.commit(command)).isSuccess, isTrue);
      expect((await local.commit(command)).isSuccess, isTrue);
      final copy = (await local.snapshot()).value.foodEntries.single;
      expect(copy.calories, 100);
      expect(copy.portionAmount, 75);
      expect(copy.meal, 'dinner');
      await alice.call(
        'deletePartnerSource',
        {'connectionId': id, 'sourceMealId': 'meal0', 'sourceRevision': 2},
      );
      expect(
        (await bob.call('partnerSummaries', day))['summaries'],
        hasLength(1),
      );
      expect(
        (((await bob.call('partnerSummaries', day))['summaries'] as List).single
            as Map)['calories'],
        4800.0,
      );
      await bob.call('disconnectPartner', {'connectionId': id});
      expect((await alice.partners.connections()).value, isEmpty);
      expect(
        (await bob.partners.request('partnerSummaries', day)).isFailure,
        isTrue,
      );
      expect((await local.snapshot()).value.foodEntries.single.calories, 100);
    },
    skip: enabled
        ? false
        : 'Run backend/functions npm run test:spark for real Auth/Firestore emulators.',
  );
}
