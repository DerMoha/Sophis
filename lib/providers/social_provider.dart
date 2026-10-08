import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/services/social/partner_projection.dart';
import 'package:sophis/services/social/social_partner_repository.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/social_account_repository.dart';
import 'package:sophis/services/social/social_runtime.dart';

/// Owns only optional social state; guest nutrition startup never opens Firebase.
final class SocialProvider extends ChangeNotifier with WidgetsBindingObserver {
  final Future<SocialRuntime> Function() _factory;
  final bool configured;
  final NutritionProvider? nutrition;
  List<PartnerConnection> partners = [];
  Timer? _partnerTimer;
  Future<void>? _projectionTask;
  bool _projectionPending = false;
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

  SocialProvider({
    Future<SocialRuntime> Function()? factory,
    bool? configured,
    this.nutrition,
  })  : _factory = factory ?? SocialRuntime.open,
        configured = configured ?? (SocialRuntime.configuration() != null) {
    nutrition?.addListener(_schedulePartnerSync);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && ready && profile != null) {
      unawaited(refreshPartners());
    }
  }

  void _schedulePartnerSync() {
    if (_closed || profile == null || _runtime == null) return;
    _partnerTimer?.cancel();
    _partnerTimer = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(syncPartnerChanges()),
    );
  }

  Future<void> refreshPartners() async {
    final runtime = _runtime;
    final epoch = _epoch;
    if (runtime == null || profile == null) return;
    final result = await runtime.partners.connections();
    if (_closed || epoch != _epoch) return;
    if (result is Success<List<PartnerConnection>>) {
      partners = result.value;
      await syncPartnerChanges();
    } else if (result is Failure<List<PartnerConnection>>) {
      partners = [];
      message = result.message;
    }
    _notify();
  }

  Future<void> syncPartnerChanges() {
    _projectionPending = true;
    return _projectionTask ??= _drainPartnerChanges();
  }

  Future<void> _drainPartnerChanges() async {
    try {
      do {
        _projectionPending = false;
        await _projectPartnerChanges();
      } while (_projectionPending && !_closed && profile != null);
    } finally {
      _projectionTask = null;
    }
  }

  Future<void> _projectPartnerChanges() async {
    final runtime = _runtime;
    final local = nutrition;
    if (_closed || runtime == null || profile == null || local == null) return;
    try {
      final session = await runtime.accounts.client.captureSession();
      if (session == null) return;
      final timeZone = (await FlutterTimezone.getLocalTimezone()).identifier;
      final projection = PartnerProjection(runtime.store);
      for (final connection in List<PartnerConnection>.of(partners)) {
        if (!await runtime.store.isCurrent(session)) return;
        final more = await projection.project(
          session: session,
          connection: connection,
          nutrition: local.store,
          goals: local.goals,
          timeZone: timeZone,
        );
        _projectionPending = _projectionPending || more;
      }
      final healthy = await runtime.queue.flush();
      if (!healthy) {
        _projectionPending = false;
      } else if (await runtime.store.nextCommand(session, DateTime.now()) !=
          null) {
        _projectionPending = true;
      }
    } catch (_) {
      if (!_closed) {
        message =
            'Partner updates could not be sent. Refresh Partners to retry.';
      }
    }
  }

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
        partners = [];
        message = null;
        _notify();
      });
      await _loadAccount();
      ready = true;
    } catch (_) {
      message = 'Partner sharing could not connect. Try again.';
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
      await refreshPartners();
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
        _epoch++;
        profile = null;
        needsProfile = false;
        partners = [];
        final result = create
            ? await runtime.auth.createAccount(email, password)
            : await runtime.auth.signIn(email, password);
        if (result is Failure<String>) {
          message = result.message;
          return;
        }
        _shownAccount = result.value;
        profile = null;
        partners = [];
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
          await refreshPartners();
        }
        if (result is Failure<SocialProfile>) message = result.message;
      });

  Future<void> refreshAccount() => _action(_loadAccount);

  Future<void> refresh() => _action(_refresh);
  Future<void> _refresh() async {
    await refreshPartners();
  }

  Future<void> signOut() => _action(() async {
        _epoch++;
        profile = null;
        partners = [];
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
    _partnerTimer?.cancel();
    nutrition?.removeListener(_schedulePartnerSync);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authChanges?.cancel());
    final runtime = _runtime;
    if (runtime != null) unawaited(runtime.close());
    super.dispose();
  }
}
