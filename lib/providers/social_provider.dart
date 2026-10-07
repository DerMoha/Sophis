import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/social_account_repository.dart';
import 'package:sophis/services/social/social_repository.dart';
import 'package:sophis/services/social/social_runtime.dart';

/// Owns only optional social state; guest nutrition startup never opens Firebase.
final class SocialProvider extends ChangeNotifier {
  final Future<SocialRuntime> Function() _factory;
  final bool configured;
  SocialRuntime? _runtime;
  StreamSubscription<Object?>? _authChanges;
  Future<void>? _opening;
  String? _shownAccount;
  int _epoch = 0;
  bool _closed = false;
  bool busy = false;
  bool ready = false;
  String? message;
  SocialProfile? profile;
  bool needsProfile = false;
  List<SocialPost> posts = [];
  SocialFeedCursor? cursor;
  bool showingCache = false;

  SocialProvider({Future<SocialRuntime> Function()? factory, bool? configured})
      : _factory = factory ?? SocialRuntime.open,
        configured = configured ?? (SocialRuntime.configuration() != null);

  int get sessionVersion => _epoch;

  String? get accountId => _runtime?.auth.accountId;
  SocialRuntime? get runtime => _runtime;

  Future<void> open() => _opening ??= _open();
  Future<void> _open() async {
    if (!configured) {
      ready = true;
      _notify();
      return;
    }
    busy = true;
    _notify();
    try {
      final runtime = await _factory();
      if (_closed) {
        await runtime.close();
        return;
      }
      _runtime = runtime;
      _shownAccount = runtime.auth.accountId;
      _authChanges = runtime.auth.changes.listen((user) {
        final uid = user?.uid;
        if (_closed || uid == _shownAccount) return;
        _shownAccount = uid;
        _epoch++;
        needsProfile = false;
        profile = null;
        posts = [];
        cursor = null;
        showingCache = false;
        message = null;
        _notify();
      });
      await _loadAccount();
      ready = true;
    } catch (_) {
      message = 'People could not connect. Try again.';
      _opening = null;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> _loadAccount() async {
    final runtime = _runtime;
    if (runtime == null || runtime.auth.accountId == null) return;
    final uid = runtime.auth.accountId;
    final epoch = _epoch;
    final result = await runtime.accounts.profile();
    if (_closed || epoch != _epoch || uid != accountId) return;
    if (result is Failure<SocialProfile?>) {
      message = result.message;
      return;
    }
    profile = result.value;
    needsProfile = profile == null;
    if (profile != null) {
      final cached = await runtime.repository.cachedFeed();
      if (_closed || epoch != _epoch || uid != accountId) return;
      posts = cached;
      showingCache = posts.isNotEmpty;
      _notify();
      await _refresh();
    }
  }

  Future<void> authenticate(
    String email,
    String password, {
    required bool create,
  }) =>
      _action(() async {
        final runtime = _runtime;
        if (runtime == null) return;
        final result = create
            ? await runtime.auth.createAccount(email, password)
            : await runtime.auth.signIn(email, password);
        if (result is Failure<String>) {
          message = result.message;
          return;
        }
        _shownAccount = result.value;
        profile = null;
        posts = [];
        await _loadAccount();
      });

  Future<void> recover(String email) => _action(() async {
        final result = await _runtime?.auth.recoverPassword(email);
        message = result is Failure<void>
            ? result.message
            : 'If an account exists, a recovery email is on its way.';
      });

  Future<void> saveProfile(String name) => _action(() async {
        final epoch = _epoch;
        final result = await _runtime?.accounts.saveProfile(name);
        if (epoch != _epoch || _closed) return;
        if (result is Success<SocialProfile>) {
          profile = result.value;
          needsProfile = false;
          await _refresh();
        }
        if (result is Failure<SocialProfile>) message = result.message;
      });

  Future<void> refreshAccount() => _action(_loadAccount);

  Future<void> refresh() => _action(_refresh);
  Future<void> _refresh() async {
    final runtime = _runtime;
    if (runtime == null || profile == null) return;
    final epoch = _epoch;
    await runtime.queue.flush();
    final result = await runtime.repository.fetchFeed();
    if (_closed || epoch != _epoch) return;
    if (result is Success<SocialFeedPage>) {
      posts = result.value.posts;
      cursor = result.value.cursor;
      showingCache = false;
    } else if (result is Failure<SocialFeedPage>) {
      message = result.message;
      if (result.errorType == ServiceErrorType.authFailed) {
        posts = [];
        showingCache = false;
      }
    }
  }

  Future<void> loadMore() => _action(() async {
        final next = cursor;
        if (next == null) return;
        final epoch = _epoch;
        final result = await _runtime?.repository.fetchFeed(cursor: next);
        if (_closed || epoch != _epoch) return;
        if (result is Success<SocialFeedPage>) {
          final byId = {for (final post in posts) post.id: post};
          for (final post in result.value.posts) {
            byId[post.id] = post;
          }
          posts = byId.values.toList();
          cursor = result.value.cursor;
        } else if (result is Failure<SocialFeedPage>) {
          message = result.message;
        }
      });

  Future<void> signOut() => _action(() async {
        _epoch++;
        profile = null;
        posts = [];
        cursor = null;
        showingCache = false;
        final result = await _runtime?.auth.signOut();
        if (result is Failure<void>) message = result.message;
        _shownAccount = accountId;
      });

  Future<void> _action(Future<void> Function() operation) async {
    if (busy || _closed) return;
    busy = true;
    message = null;
    _notify();
    try {
      await operation();
    } catch (_) {
      message = 'Could not complete this action. Try again.';
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(_authChanges?.cancel());
    final runtime = _runtime;
    if (runtime != null) unawaited(runtime.close());
    super.dispose();
  }
}
