import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'package:sophis/models/partner_day.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/services/partner/firebase_partner_backend.dart';
import 'package:sophis/services/partner/partner_backend.dart';

enum PartnerStatus {
  unavailable,
  loading,
  signedOut,
  needsName,
  single,
  paired
}

/// One partner per person. While paired, the last [sharedDays] diary days are
/// mirrored to the partner and the partner's today is watched live.
class PartnerProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const sharedDays = 7;

  final NutritionProvider nutrition;
  final Future<PartnerBackend> Function() _open;
  PartnerBackend? _backend;

  PartnerStatus status;
  PartnerProfile? profile;
  PartnerLink? link;
  PartnerDay? partnerToday;
  PartnerInvite? invite;
  PartnerError? error;
  bool busy = false;

  StreamSubscription<String?>? _authSubscription;
  StreamSubscription<PartnerProfile?>? _profileSubscription;
  StreamSubscription<PartnerDay?>? _todaySubscription;
  String? _todayKey;
  Timer? _syncTimer;
  int _session = 0;
  bool _disposed = false;

  /// Signatures of days already sent this session; unchanged days are skipped.
  final Map<String, String> _written = {};

  PartnerProvider({
    required this.nutrition,
    Future<PartnerBackend> Function()? open,
    bool? supported,
  })  : _open = open ?? FirebasePartnerBackend.open,
        status = (supported ?? FirebasePartnerBackend.supported)
            ? PartnerStatus.loading
            : PartnerStatus.unavailable {
    nutrition.addListener(_scheduleSync);
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> start() async {
    if (status == PartnerStatus.unavailable || _backend != null) return;
    try {
      final backend = await _open();
      if (_disposed) return;
      _backend = backend;
      _authSubscription = backend.authChanges().listen(_onAuth);
    } catch (_) {
      status = PartnerStatus.unavailable;
      _notify();
    }
  }

  void _onAuth(String? uid) {
    _session++;
    _profileSubscription?.cancel();
    _clearPartner();
    profile = null;
    invite = null;
    if (uid == null) {
      status = PartnerStatus.signedOut;
    } else {
      status = PartnerStatus.loading;
      _profileSubscription = _backend!.watchProfile().listen(
            _onProfile,
            onError: (Object _) {},
          );
    }
    _notify();
  }

  Future<void> _onProfile(PartnerProfile? next) async {
    final session = _session;
    profile = next;
    final connectionId = next?.connectionId;
    if (next == null) {
      _clearPartner();
      status = PartnerStatus.needsName;
    } else if (connectionId == null) {
      _clearPartner();
      status = PartnerStatus.single;
    } else if (link?.connectionId != connectionId) {
      try {
        final resolved = await _backend!.link(connectionId);
        if (session != _session || profile?.connectionId != connectionId) {
          return;
        }
        link = resolved;
        invite = null;
        status = PartnerStatus.paired;
        _watchToday();
        unawaited(_sync());
      } on PartnerException catch (e) {
        error = e.error;
      }
    }
    _notify();
  }

  void _clearPartner() {
    _todaySubscription?.cancel();
    _todaySubscription = null;
    _syncTimer?.cancel();
    link = null;
    partnerToday = null;
    _todayKey = null;
    _written.clear();
  }

  void _watchToday() {
    final current = link;
    if (current == null) return;
    final key = PartnerDay.key(DateTime.now());
    if (key == _todayKey) return;
    _todayKey = key;
    partnerToday = null;
    _todaySubscription?.cancel();
    _todaySubscription = _backend!.watchDay(current, key).listen(
      (day) {
        partnerToday = day;
        _notify();
      },
      onError: (Object _) {},
    );
  }

  Stream<PartnerDay?> watchPartnerDay(DateTime date) {
    final current = link;
    final backend = _backend;
    if (current == null || backend == null) return Stream.value(null);
    return backend.watchDay(current, PartnerDay.key(date));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || link == null) return;
    _watchToday();
    _scheduleSync();
    _notify();
  }

  void _scheduleSync() {
    if (link == null) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 800), _sync);
  }

  /// Writes are not awaited: Firestore queues them offline and confirms later.
  Future<void> _sync() async {
    final current = link;
    final backend = _backend;
    if (current == null || backend == null) return;
    final now = DateTime.now();
    for (var offset = 0; offset < sharedDays; offset++) {
      final date = DateTime(now.year, now.month, now.day - offset);
      final day = PartnerDay(
        date: PartnerDay.key(date),
        goals: nutrition.goals,
        burned: offset == 0 ? nutrition.burnedCalories : 0,
        entries: nutrition.getEntriesForDate(date),
      );
      final signature = jsonEncode(day.toJson());
      if (_written[day.date] == signature) continue;
      _written[day.date] = signature;
      unawaited(
        backend.writeDay(current.connectionId, day).catchError((Object _) {
          if (_written[day.date] == signature) _written.remove(day.date);
        }),
      );
    }
  }

  Future<bool> signIn(String email, String password) =>
      _run((backend) => backend.signIn(email, password));

  Future<bool> createAccount(String email, String password) =>
      _run((backend) => backend.createAccount(email, password));

  Future<bool> resetPassword(String email) =>
      _run((backend) => backend.resetPassword(email));

  Future<bool> saveName(String name) =>
      _run((backend) => backend.saveName(name));

  Future<bool> createInvite() => _run((backend) async {
        invite = await backend.createInvite();
      });

  Future<bool> acceptInvite(String code) =>
      _run((backend) => backend.acceptInvite(code));

  Future<bool> disconnect() => _run((backend) async {
        final current = link;
        if (current != null) await backend.disconnect(current);
      });

  Future<bool> signOut() => _run((backend) => backend.signOut());

  Future<bool> deleteAccount() =>
      _run((backend) => backend.deleteAccount(link));

  void clearError() {
    if (error == null) return;
    error = null;
    _notify();
  }

  Future<bool> _run(
    Future<void> Function(PartnerBackend backend) action,
  ) async {
    final backend = _backend;
    if (backend == null || busy) return false;
    busy = true;
    error = null;
    _notify();
    try {
      await action(backend);
      return true;
    } on PartnerException catch (e) {
      error = e.error;
      return false;
    } catch (_) {
      error = PartnerError.unknown;
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _syncTimer?.cancel();
    nutrition.removeListener(_scheduleSync);
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    _todaySubscription?.cancel();
    super.dispose();
  }
}
