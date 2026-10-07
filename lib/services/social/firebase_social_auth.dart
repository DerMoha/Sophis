import 'dart:async';
import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/social_callable_client.dart';
import 'package:sophis/services/social/social_local_store.dart';

/// Firebase auth is scoped to the optional social app. The private local diary
/// is never touched by login, logout, recovery or an authentication event.
final class FirebaseSocialAuth
    implements SocialCredentials, SocialCredentialSession {
  final FirebaseAuth auth;
  final FirebaseAppCheck? appCheck;
  final SocialLocalStore store;
  late final StreamSubscription<User?> _subscription;
  Future<void> _accountSync = Future<void>.value();
  final Completer<void> _ready = Completer<void>();
  Object? _syncError;
  int _epoch = 0;
  String? _observedUid;
  bool _busy = false;
  bool _closed = false;

  FirebaseSocialAuth({required this.auth, required this.store, this.appCheck}) {
    _observedUid = auth.currentUser?.uid;
    _subscription = auth.authStateChanges().listen(
      (user) {
        if (_observedUid != user?.uid) {
          _epoch++;
          _observedUid = user?.uid;
        }
        _accountSync = _accountSync.then((_) async {
          final current = await store.session();
          final uid = user?.uid;
          if (current.accountId != uid) await store.switchAccount(uid);
          _syncError = null;
          if (!_ready.isCompleted) _ready.complete();
        }).catchError((Object error, StackTrace trace) {
          _syncError = error;
          if (!_ready.isCompleted) _ready.completeError(error, trace);
        });
      },
      onError: (Object error, StackTrace trace) {
        _syncError = error;
        if (!_ready.isCompleted) _ready.completeError(error, trace);
      },
    );
  }

  Future<void> ready() async {
    await _ready.future.timeout(const Duration(seconds: 15));
    await _accountSync;
  }

  Stream<User?> get changes => auth.authStateChanges();

  @override
  String? get accountId => _closed ? null : auth.currentUser?.uid;

  @override
  int get authenticationVersion => _epoch;

  @override
  Future<SocialTokens> tokensFor(String accountId) async {
    try {
      return await _tokensFor(accountId);
    } on FirebaseAuthException catch (error) {
      throw SocialCredentialFailure(_authFailure(error).errorType);
    } on FirebaseException {
      throw const SocialCredentialFailure(ServiceErrorType.network);
    }
  }

  Future<SocialTokens> _tokensFor(String accountId) async {
    await _accountSync;
    if (_syncError != null) {
      throw StateError('Social account could not synchronize');
    }
    final epoch = _epoch;
    final user = auth.currentUser;
    if (_closed || user == null || user.uid != accountId) {
      throw StateError('Social account changed');
    }
    final idToken = await user.getIdToken();
    final appToken = await appCheck?.getToken();
    if (_closed ||
        _epoch != epoch ||
        this.accountId != accountId ||
        idToken == null) {
      throw StateError('Social account changed');
    }
    // Native getIdToken can resolve via the app's current user. Verify the
    // returned token's subject too, rather than trusting the captured User UID.
    final segments = idToken.split('.');
    if (segments.length != 3) throw StateError('Invalid authentication token');
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
    );
    if (claims is! Map || claims['sub'] != accountId) {
      throw StateError('Social token identity changed');
    }
    return SocialTokens(
      accountId: accountId,
      idToken: idToken,
      appCheckToken: appToken,
    );
  }

  Future<ServiceResult<String>> signIn(String email, String password) =>
      _authenticate(
        () => auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );

  Future<ServiceResult<String>> createAccount(String email, String password) =>
      _authenticate(
        () => auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );

  Future<ServiceResult<String>> _authenticate(
    Future<UserCredential> Function() operation,
  ) async {
    if (_busy || _closed) {
      return const Failure(
        ServiceErrorType.authFailed,
        'An account action is already in progress.',
      );
    }
    _busy = true;
    try {
      // Invalidate even a same-UID reauthentication before credentials change.
      _epoch++;
      await store.switchAccount(null);
      final result = await operation();
      await _accountSync;
      final uid = result.user?.uid;
      if (_closed || uid == null || auth.currentUser?.uid != uid) {
        throw StateError('Account changed');
      }
      // The explicit authentication already invalidated the old epoch. A
      // delayed native replay of this same UID is not another account switch.
      _observedUid = uid;
      // Serialize fallback reconciliation with native auth events so two
      // concurrent repairs cannot invalidate a newly initiated profile request.
      _accountSync = _accountSync.then((_) async {
        final session = await store.session();
        if (session.accountId != uid) await store.switchAccount(uid);
        _syncError = null;
      }).catchError((Object error, StackTrace trace) {
        _syncError = error;
      });
      await _accountSync;
      if (_syncError != null || _closed || auth.currentUser?.uid != uid) {
        throw StateError('Account changed');
      }
      return Success(uid);
    } on FirebaseAuthException catch (error) {
      return _authFailure(error);
    } catch (_) {
      return const Failure(
        ServiceErrorType.authFailed,
        'Could not sign in. Try again.',
      );
    } finally {
      _busy = false;
    }
  }

  Future<ServiceResult<void>> recoverPassword(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
      return const Success(null);
    } on FirebaseAuthException catch (error) {
      final failure = _authFailure(error);
      // Avoid disclosing whether an email has an account on older projects.
      if (error.code == 'user-not-found') return const Success(null);
      return Failure(failure.errorType, failure.message);
    } catch (_) {
      return const Failure(
        ServiceErrorType.network,
        'Could not request recovery. Try again.',
      );
    }
  }

  Future<ServiceResult<void>> signOut() async {
    if (_busy || _closed) {
      return const Failure(
        ServiceErrorType.authFailed,
        'An account action is already in progress.',
      );
    }
    _busy = true;
    try {
      _epoch++;
      await store.switchAccount(null);
      await auth.signOut();
      _observedUid = null;
      await _accountSync;
      return const Success(null);
    } catch (_) {
      return const Failure(
        ServiceErrorType.authFailed,
        'Could not sign out. Try again.',
      );
    } finally {
      _busy = false;
    }
  }

  Failure<String> _authFailure(FirebaseAuthException error) =>
      switch (error.code) {
        'network-request-failed' => const Failure(
            ServiceErrorType.network,
            'Connect to the internet and try again.',
          ),
        'too-many-requests' => const Failure(
            ServiceErrorType.rateLimited,
            'Too many attempts. Try again later.',
          ),
        'weak-password' => const Failure(
            ServiceErrorType.authFailed,
            'Choose a stronger password.',
          ),
        'invalid-email' => const Failure(
            ServiceErrorType.authFailed,
            'Enter a valid email address.',
          ),
        'email-already-in-use' => const Failure(
            ServiceErrorType.authFailed,
            'Try signing in or recovering your password.',
          ),
        _ => const Failure(
            ServiceErrorType.authFailed,
            'Could not sign in. Check your details or recover your password.',
          ),
      };

  Future<void> close() async {
    _closed = true;
    _epoch++;
    await _subscription.cancel();
    await _accountSync;
  }
}
