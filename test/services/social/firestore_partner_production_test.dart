import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/firestore_partner_client.dart';
import 'package:sophis/services/social/social_account_repository.dart';
import 'package:sophis/services/social/social_callable_client.dart';
import 'package:sophis/services/social/social_local_store.dart';
import 'package:sophis/services/social/social_partner_repository.dart';

/// Deliberate, opt-in deployment smoke test. Synthetic fixtures only. It leaves
/// a disconnected connection with revoked synthetic data, and removes its Auth
/// users. Never run automatically or against an inferred/default project.
final class _Credentials implements SocialCredentials {
  @override
  final String accountId;
  final String token;
  const _Credentials(this.accountId, this.token);
  @override
  Future<SocialTokens> tokensFor(String uid) async =>
      SocialTokens(accountId: accountId, idToken: token);
}

void main() {
  test(
    'verified the deployed Spark partner flow with three isolated synthetic accounts',
    () async {
      final config = jsonDecode(
        await File('config/firebase.production.json').readAsString(),
      ) as Map<String, dynamic>;
      expect(
        config['SOCIAL_PROJECT_ID'],
        'sophis-d2953',
        reason: 'Only the explicitly registered project may be tested.',
      );
      final key = config['SOCIAL_ANDROID_API_KEY'] as String;
      final httpClient = http.Client();
      final people = <({
        FirestorePartnerClient client,
        SocialLocalStore store,
        _Credentials credentials
      })>[];
      String? connectionId;
      var disconnected = false;
      Future<Map<String, dynamic>> call(
        FirestorePartnerClient client,
        String action,
        Map<String, dynamic> payload,
      ) async {
        final result = await client.call(
          (await client.captureSession())!,
          action,
          payload,
        );
        expect(
          result.isSuccess,
          isTrue,
          reason:
              '$action: ${result is Failure<Object?> ? result.message : ''}',
        );
        return result.value as Map<String, dynamic>;
      }

      addTearDown(() async {
        if (connectionId != null && people.isNotEmpty) {
          final first = people.first.client;
          if (!disconnected) {
            await call(
                first, 'disconnectPartner', {'connectionId': connectionId},);
          }
          await call(first, 'deletePartnerSource', {
            'connectionId': connectionId,
            'sourceMealId': 'synthetic-rice',
            'sourceRevision': 2,
          });
        }
        for (final person in people) {
          final deleted = await httpClient.post(
            Uri.https(
              'identitytoolkit.googleapis.com',
              '/v1/accounts:delete',
              {'key': key},
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': person.credentials.token}),
          );
          expect(
            deleted.statusCode,
            200,
            reason: 'Synthetic Auth fixture cleanup failed.',
          );
          await person.store.close();
        }
        httpClient.close();
      });
      Future<FirestorePartnerClient> person(String name) async {
        final marker = DateTime.now().microsecondsSinceEpoch;
        final random = Random.secure();
        final password =
            base64Url.encode(List.generate(32, (_) => random.nextInt(256)));
        final response = await httpClient.post(
          Uri.https(
            'identitytoolkit.googleapis.com',
            '/v1/accounts:signUp',
            {'key': key},
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': 'sophis-qa-$name-$marker@example.invalid',
            'password': password,
            'returnSecureToken': true,
          }),
        );
        expect(
          response.statusCode,
          200,
          reason: 'Production email/password registration did not succeed.',
        );
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final credentials =
            _Credentials(data['localId'] as String, data['idToken'] as String);
        final store = SocialLocalStore(NativeDatabase.memory());
        await store.switchAccount(credentials.accountId);
        final client = FirestorePartnerClient(
          credentials: credentials,
          store: store,
          httpClient: httpClient,
          projectId: config['SOCIAL_PROJECT_ID'] as String,
        );
        people.add((client: client, store: store, credentials: credentials));
        await call(
          client,
          'setProfile',
          {'displayName': 'QA $name (synthetic test)'},
        );
        return client;
      }

      final author = await person('author'),
          recipient = await person('recipient'),
          third = await person('unrelated');
      final accounts =
          SocialAccountRepository(client: author, store: people.first.store);
      final invitation = await accounts.invite('partner');
      expect(invitation.isSuccess, isTrue);
      final preview = await call(
        recipient,
        'previewInvitation',
        {'token': invitation.value.token},
      );
      expect(preview['audience'], 'partner');
      await call(
        recipient,
        'requestPartner',
        {'token': invitation.value.token},
      );
      final partners = SocialPartnerRepository(author);
      final connection = (await partners.connections()).value.single;
      connectionId = connection.id;
      await call(author, 'acceptPartner', {'connectionId': connectionId});
      final current = (await partners.connections()).value.single;
      final now = DateTime.now().millisecondsSinceEpoch;
      final payload = <String, dynamic>{
        'connectionId': connectionId,
        'sourceMealId': 'synthetic-rice',
        'sourceRevision': 1,
        'consentRevision': current.ownSettings['revision'],
        'originallyLoggedAt': now,
        'changedAt': now,
        'localDate': '2026-10-08',
        'timeZone': 'Europe/Berlin',
      };
      await call(author, 'syncPartnerMeal', {
        ...payload,
        'mealCategory': 'lunch',
        'snapshot': {
          'schemaVersion': 1,
          'title': 'Synthetic rice',
          'servings': 1,
          'items': [
            {
              'name': 'Synthetic rice',
              'calories': 200.0,
              'protein': 4.0,
              'carbs': 44.0,
              'fat': 1.0,
              'fiber': 2.0,
            }
          ],
        },
      });
      await call(author, 'syncPartnerContribution', {
        ...payload,
        'calories': 200.0,
        'protein': 4.0,
        'carbs': 44.0,
        'fat': 1.0,
      });
      await call(author, 'syncPartnerGoals', {
        'connectionId': connectionId,
        'consentRevision': current.ownSettings['revision'],
        'sourceRevision': 1,
        'goals': {
          'calories': 2000.0,
          'protein': 100.0,
          'carbs': 250.0,
          'fat': 70.0,
        },
        'timeZone': 'Europe/Berlin',
      });
      final day = {
        'connectionId': connectionId,
        'localDate': '2026-10-08',
        'timeZone': 'Europe/Berlin',
      };
      expect(
        (await call(recipient, 'partnerMeals', day))['meals'],
        hasLength(1),
      );
      final summaries =
          (await call(recipient, 'partnerSummaries', day))['summaries'] as List;
      expect((summaries.single as Map)['calories'], 200.0);
      expect(
        (await call(recipient, 'partnerGoals', {'connectionId': connectionId}))[
            'goals'],
        hasLength(1),
      );
      expect(
        (await SocialPartnerRepository(third).request('partnerMeals', day))
            .isFailure,
        isTrue,
      );
      expect(
        (await partners
                .request('disconnectPartner', {'connectionId': connectionId}))
            .isSuccess,
        isTrue,
      );
      disconnected = true;
      expect(
        (await SocialPartnerRepository(recipient).request('partnerMeals', day))
            .isFailure,
        isTrue,
      );
    },
    skip: Platform.environment['SOPHIS_VERIFY_DEPLOYED_SPARK'] == 'sophis-d2953'
        ? false
        : 'Explicit production deployment verification only.',
  );
}
