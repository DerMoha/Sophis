import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sophis/services/social/firebase_social_auth.dart';
import 'package:sophis/services/social/social_local_store.dart';

class _Auth extends Mock implements FirebaseAuth {}

class _User extends Mock implements User {}

void main() {
  late _Auth auth;
  late _User alice;
  late _User bob;
  late SocialLocalStore store;
  late FirebaseSocialAuth service;
  late StreamController<User?> changes;
  User? current;
  String token(String uid) => 'header.${base64Url.encode(
        utf8.encode(
          jsonEncode({
            'sub': uid,
          }),
        ),
      )}.signature';

  setUp(() async {
    store = SocialLocalStore(NativeDatabase.memory());
    await store.switchAccount('alice');
    auth = _Auth();
    alice = _User();
    bob = _User();
    when(() => alice.uid).thenReturn('alice');
    when(() => bob.uid).thenReturn('bob');
    current = alice;
    changes = StreamController<User?>.broadcast(sync: true);
    when(() => auth.currentUser).thenAnswer((_) => current);
    when(() => auth.authStateChanges()).thenAnswer((_) => changes.stream);
    when(() => alice.getIdToken()).thenAnswer((_) async => token('alice'));
    service = FirebaseSocialAuth(auth: auth, store: store);
  });
  tearDown(() async {
    await service.close();
    await changes.close();
    await store.close();
  });

  group('FirebaseSocialAuth', () {
    test('obtained tokens only for the requested subject', () async {
      expect((await service.tokensFor('alice')).accountId, 'alice');
      expect(() => service.tokensFor('bob'), throwsStateError);
    });
    test('rejected native token refresh resolving under another user',
        () async {
      when(() => alice.getIdToken()).thenAnswer((_) async => token('bob'));
      expect(() => service.tokensFor('alice'), throwsStateError);
    });
    test('rejected refresh across sign-out and same-account sign-in', () async {
      final originalSession = await store.session();
      final refresh = Completer<String?>();
      when(() => alice.getIdToken()).thenAnswer((_) => refresh.future);
      final pending = service.tokensFor('alice');
      final check = expectLater(pending, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      current = null;
      changes.add(null);
      current = alice;
      changes.add(alice);
      refresh.complete(token('alice'));
      await check;
      await service.tokensFor('alice');
      expect(await store.isCurrent(originalSession), isFalse);
    });
    test('cleared cached content and queued work before logout returned',
        () async {
      final session = await store.session();
      await store.cacheFeed(
        session,
        [
          {'id': 'private'},
        ],
        DateTime.now(),
      );
      await store.enqueue(
        session,
        SocialQueuedCommand(
          operationId: 'one',
          action: 'deletePost',
          targetId: 'post',
          payload: {'postId': 'post'},
          createdAt: DateTime.now(),
        ),
      );
      when(() => auth.signOut()).thenAnswer((_) async {
        expect((await store.session()).accountId, isNull);
        expect(await store.cachedFeed(session), isEmpty);
        current = null;
        changes.add(null);
      });
      expect((await service.signOut()).isSuccess, isTrue);
      expect(await store.nextCommand(session, DateTime.now()), isNull);
    });
    test('cleared account content when authentication changed externally',
        () async {
      final session = await store.session();
      await store.cacheFeed(
        session,
        [
          {'id': 'private'},
        ],
        DateTime.now(),
      );
      when(() => bob.getIdToken()).thenAnswer((_) async => token('bob'));
      current = bob;
      changes.add(bob);
      await service.tokensFor('bob');
      expect((await store.session()).accountId, 'bob');
      expect(await store.cachedFeed(session), isEmpty);
    });
    test('returned generic password-recovery success for unknown email',
        () async {
      when(() => auth.sendPasswordResetEmail(email: 'person@example.com'))
          .thenThrow(FirebaseAuthException(code: 'user-not-found'));
      expect(
        (await service.recoverPassword('person@example.com')).isSuccess,
        isTrue,
      );
    });
  });
}
