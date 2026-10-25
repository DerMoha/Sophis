import 'dart:async';

import 'package:sophis/models/partner_day.dart';
import 'package:sophis/services/partner/partner_backend.dart';

/// In-memory partner backend; tests drive auth and profile changes.
class FakePartnerBackend implements PartnerBackend {
  final _auth = StreamController<String?>.broadcast();
  final _profile = StreamController<PartnerProfile?>.broadcast();
  final _days = <String, StreamController<PartnerDay?>>{};

  @override
  String? uid;
  final Map<String, PartnerDay> written = {};
  int writeCount = 0;
  PartnerError? failNext;
  String partnerName = 'Lena';

  void emitAuth(String? id) {
    uid = id;
    _auth.add(id);
  }

  void emitProfile(PartnerProfile? profile) => _profile.add(profile);

  void emitPartnerDay(String date, PartnerDay? day) =>
      _dayController(date).add(day);

  StreamController<PartnerDay?> _dayController(String date) =>
      _days.putIfAbsent(date, StreamController<PartnerDay?>.broadcast);

  Future<void> _maybeFail() async {
    final error = failNext;
    failNext = null;
    if (error != null) throw PartnerException(error);
  }

  @override
  Stream<String?> authChanges() => _auth.stream;

  @override
  Future<void> signIn(String email, String password) => _maybeFail();

  @override
  Future<void> createAccount(String email, String password) => _maybeFail();

  @override
  Future<void> resetPassword(String email) => _maybeFail();

  @override
  Future<void> signOut() => _maybeFail();

  @override
  Future<void> deleteAccount(PartnerLink? link) => _maybeFail();

  @override
  Stream<PartnerProfile?> watchProfile() => _profile.stream;

  @override
  Future<void> saveName(String name) => _maybeFail();

  @override
  Future<PartnerInvite> createInvite() async {
    await _maybeFail();
    return PartnerInvite(
      code: 'ABCD2345',
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
    );
  }

  @override
  Future<void> acceptInvite(String code) => _maybeFail();

  @override
  Future<PartnerLink> link(String connectionId) async => PartnerLink(
        connectionId: connectionId,
        partnerId: 'partner',
        partnerName: partnerName,
      );

  @override
  Future<void> disconnect(PartnerLink link) => _maybeFail();

  @override
  Future<void> writeDay(String connectionId, PartnerDay day) async {
    writeCount++;
    written[day.date] = day;
  }

  @override
  Stream<PartnerDay?> watchDay(PartnerLink link, String date) =>
      _dayController(date).stream;
}
