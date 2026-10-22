import 'dart:async';

import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/social_provider.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/callable_social_repository.dart';
import 'package:sophis/services/social/firebase_social_auth.dart';
import 'package:sophis/services/social/social_account_repository.dart';
import 'package:sophis/services/social/social_callable_client.dart';
import 'package:sophis/services/social/social_local_store.dart';
import 'package:sophis/services/social/social_queue_runner.dart';
import 'package:sophis/services/social/social_runtime.dart';
import 'package:sophis/ui/screens/social/social_partners_screen.dart';
import 'package:sophis/ui/screens/social/people_screen.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as timezone;
import 'package:intl/intl.dart';

class _Auth extends Mock implements FirebaseAuth {}

class _User extends Mock implements User {}

class _Nutrition extends Mock implements NutritionProvider {}

class _Client implements SocialClient {
  final SocialLocalStore store;
  final sending = Completer<void>();
  final upload = Completer<ServiceResult<void>>();
  Future<ServiceResult<Object?>> Function(String)? respond;
  _Client(this.store);

  @override
  String get accountId => 'alice';
  @override
  Future<SocialSession?> captureSession() => store.session();
  @override
  Future<ServiceResult<Object?>> call(
    SocialSession session,
    String action,
    Map<String, dynamic> payload,
  ) async =>
      respond != null
          ? await respond!(action)
          : Success<Object?>(
              action == 'ownProfile'
                  ? {
                      'profile': {'accountId': 'alice', 'displayName': 'Alice'},
                    }
                  : {'connections': <Object>[]},
            );
  @override
  Future<ServiceResult<void>> send(
    SocialSession session,
    SocialQueuedCommand command,
  ) {
    if (!sending.isCompleted) sending.complete();
    return upload.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('showed saved partner data before startup refresh finished',
      (tester) async {
    tz.initializeTimeZones();
    final fixture = (await tester.runAsync(() async {
      final store = SocialLocalStore(NativeDatabase.memory());
      final session = await store.switchAccount('alice');
      final auth = _Auth();
      final user = _User();
      when(() => user.uid).thenReturn('alice');
      when(() => auth.currentUser).thenReturn(user);
      when(() => auth.authStateChanges())
          .thenAnswer((_) => const Stream.empty());
      final service = FirebaseSocialAuth(auth: auth, store: store);
      final client = _Client(store);
      final runtime = SocialRuntime(
        auth: service,
        repository: CallableSocialRepository(
          client: client,
          store: store,
          signOut: service.signOut,
        ),
        accounts: SocialAccountRepository(client: client, store: store),
        queue: SocialQueueRunner(store: store, transport: client),
        store: store,
        httpClient:
            MockClient((_) async => throw StateError('Unexpected HTTP')),
      );
      await store.cachePartnerResponse(
        session,
        'ownProfile',
        {'accountId': 'alice', 'displayName': 'Alice'},
      );
      client.respond = (action) async => Success<Object?>(
            switch (action) {
              'partners' => {
                  'connections': [
                    {
                      'id': 'one',
                      'displayName': 'Bob',
                      'participants': ['alice', 'bob'],
                      'inviterId': 'alice',
                      'status': 'accepted',
                      'settings': {
                        'alice': {'revision': 1},
                        'bob': {'revision': 1},
                      },
                    }
                  ],
                },
              'partnerGoals' => {
                  'goals': [
                    {'authorId': 'bob', 'timeZone': 'Europe/Berlin'},
                  ],
                },
              'partnerSummaries' => {
                  'summaries': [
                    {'authorId': 'bob', 'calories': 456.0},
                  ],
                },
              _ => {'meals': <Object>[], 'cursor': null},
            },
          );
      await runtime.partners.connections();
      await runtime.partners.request('partnerGoals', {'connectionId': 'one'});
      final date = DateFormat('yyyy-MM-dd').format(
        timezone.TZDateTime.now(timezone.getLocation('Europe/Berlin')),
      );
      final payload = {
        'connectionId': 'one',
        'localDate': date,
        'timeZone': 'Europe/Berlin',
      };
      await runtime.partners.request('partnerSummaries', payload);
      await runtime.partners.request('partnerMeals', payload);
      final started = Completer<void>();
      final response = Completer<ServiceResult<Object?>>();
      client.respond = (action) async {
        if (action == 'ownProfile') {
          started.complete();
          return response.future;
        }
        return const Failure<Object?>(ServiceErrorType.network, 'Offline');
      };
      final social =
          SocialProvider(configured: true, factory: () async => runtime);
      final opening = social.open();
      await started.future;
      return (social: social, response: response, opening: opening);
    }))!;
    addTearDown(fixture.social.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: fixture.social,
        child: const MaterialApp(home: PeopleScreen()),
      ),
    );
    for (var i = 0;
        i < 20 &&
            find
                .textContaining('Showing saved partner data')
                .evaluate()
                .isEmpty;
        i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(fixture.response.isCompleted, isFalse);
    expect(find.textContaining('Showing saved partner data'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    await tester.runAsync(() async {
      fixture.response.complete(
        const Failure<Object?>(ServiceErrorType.network, 'Offline'),
      );
      await fixture.opening;
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Showing saved partner data'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is LinearProgressIndicator && widget.value == null,
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('kept action errors visible and stopped loading after sign-out',
      (tester) async {
    final fixture = (await tester.runAsync(() async {
      final store = SocialLocalStore(NativeDatabase.memory());
      final auth = _Auth();
      final user = _User();
      User? current = user;
      when(() => user.uid).thenReturn('alice');
      when(() => auth.currentUser).thenAnswer((_) => current);
      when(() => auth.authStateChanges())
          .thenAnswer((_) => const Stream.empty());
      when(() => auth.signOut()).thenAnswer((_) async => current = null);
      final service = FirebaseSocialAuth(auth: auth, store: store);
      final client = _Client(store);
      final pending = Completer<ServiceResult<Object?>>();
      var attempts = 0;
      client.respond = (action) async {
        if (action == 'ownProfile') {
          return const Success<Object?>({
            'profile': {'accountId': 'alice', 'displayName': 'Alice'},
          });
        }
        if (action == 'acceptPartner') {
          attempts++;
          if (attempts == 1) {
            return const Failure<Object?>(ServiceErrorType.network, 'Offline');
          }
          return pending.future;
        }
        return const Success<Object?>({
          'connections': [
            {
              'id': 'one',
              'displayName': 'Bob',
              'participants': ['alice', 'bob'],
              'inviterId': 'alice',
              'status': 'pending',
              'settings': {
                'alice': {'revision': 0},
                'bob': {'revision': 0},
              },
            },
          ],
        });
      };
      final runtime = SocialRuntime(
        auth: service,
        repository: CallableSocialRepository(
          client: client,
          store: store,
          signOut: service.signOut,
        ),
        accounts: SocialAccountRepository(client: client, store: store),
        queue: SocialQueueRunner(store: store, transport: client),
        store: store,
        httpClient:
            MockClient((_) async => throw StateError('Unexpected HTTP')),
      );
      final social =
          SocialProvider(configured: true, factory: () async => runtime);
      await store.switchAccount('alice');
      await social.open();
      return (social: social, pending: pending);
    }))!;
    final social = fixture.social;
    final pending = fixture.pending;
    addTearDown(social.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: social,
        child: const MaterialApp(home: SocialPartnersScreen()),
      ),
    );
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accept partner'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(find.text('Offline'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.tap(find.text('Accept partner'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.runAsync(() async {
      await social.signOut();
      pending.complete(
        const Failure<Object?>(ServiceErrorType.authFailed, 'Old account'),
      );
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Old account'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('opened partner sharing while a queued upload was still pending',
      () async {
    final store = SocialLocalStore(NativeDatabase.memory());
    final session = await store.switchAccount('alice');
    final auth = _Auth();
    final user = _User();
    when(() => user.uid).thenReturn('alice');
    when(() => auth.currentUser).thenReturn(user);
    when(() => auth.authStateChanges()).thenAnswer((_) => const Stream.empty());
    final service = FirebaseSocialAuth(auth: auth, store: store);
    final client = _Client(store);
    final runtime = SocialRuntime(
      auth: service,
      repository: CallableSocialRepository(
        client: client,
        store: store,
        signOut: service.signOut,
      ),
      accounts: SocialAccountRepository(client: client, store: store),
      queue: SocialQueueRunner(store: store, transport: client),
      store: store,
      httpClient: MockClient((_) async => throw StateError('Unexpected HTTP')),
    );
    await store.enqueue(
      session,
      SocialQueuedCommand(
        operationId: 'pending',
        action: 'deletePartnerSource',
        targetId: 'meal',
        payload: {},
        createdAt: DateTime.now(),
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (_) async => 'Europe/Berlin',
    );
    final social = SocialProvider(
      configured: true,
      factory: () async => runtime,
      nutrition: _Nutrition(),
    );
    try {
      await social.open().timeout(const Duration(seconds: 2));
      await client.sending.future.timeout(const Duration(seconds: 2));
      expect(social.ready, isTrue);
      expect(social.busy, isFalse);
      expect(client.upload.isCompleted, isFalse);
      client.upload.complete(const Success<void>(null));
      await social.syncPartnerChanges();

      var notifications = 0;
      social.addListener(() => notifications++);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_timezone'),
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      await social.syncPartnerChanges();
      expect(social.message, contains('could not be sent'));
      expect(notifications, greaterThan(0));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_timezone'),
        (_) async => 'Europe/Berlin',
      );
      await social.syncPartnerChanges();
      expect(social.message, isNull);
    } finally {
      if (!client.upload.isCompleted) {
        client.upload.complete(const Success<void>(null));
      }
      await social.syncPartnerChanges();
      social.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_timezone'),
        null,
      );
    }
  });
}
