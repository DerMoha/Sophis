import 'package:sophis/models/partner_day.dart';

/// Signed-in person's sharing profile.
final class PartnerProfile {
  final String displayName;
  final String? connectionId;

  const PartnerProfile({required this.displayName, this.connectionId});
}

/// The single accepted partner of the signed-in person.
final class PartnerLink {
  final String connectionId;
  final String partnerId;
  final String partnerName;

  const PartnerLink({
    required this.connectionId,
    required this.partnerId,
    required this.partnerName,
  });
}

final class PartnerInvite {
  final String code;
  final DateTime expiresAt;

  const PartnerInvite({required this.code, required this.expiresAt});

  Uri get link => Uri(
        scheme: 'sophis',
        host: 'partner',
        queryParameters: {'code': code},
      );

  /// Codes avoid look-alike characters (0/O, 1/I) so they can be typed.
  static final pattern = RegExp(r'^[A-HJ-NP-Z2-9]{8}$');

  static String? normalize(String input) {
    final code = input.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    return pattern.hasMatch(code) ? code : null;
  }
}

enum PartnerError {
  network,
  invalidCredentials,
  emailInUse,
  weakPassword,
  invalidEmail,
  tooManyRequests,
  requiresRecentLogin,
  inviteInvalid,
  ownInvite,
  alreadyPaired,
  unknown,
}

final class PartnerException implements Exception {
  final PartnerError error;
  const PartnerException(this.error);

  @override
  String toString() => 'PartnerException(${error.name})';
}

/// Firebase stays behind this seam; methods throw [PartnerException].
abstract interface class PartnerBackend {
  String? get uid;
  Stream<String?> authChanges();
  Future<void> signIn(String email, String password);
  Future<void> createAccount(String email, String password);
  Future<void> resetPassword(String email);
  Future<void> signOut();
  Future<void> deleteAccount(PartnerLink? link);

  Stream<PartnerProfile?> watchProfile();
  Future<void> saveName(String name);
  Future<PartnerInvite> createInvite();
  Future<void> acceptInvite(String code);
  Future<PartnerLink> link(String connectionId);
  Future<void> disconnect(PartnerLink link);

  Future<void> writeDay(String connectionId, PartnerDay day);
  Stream<PartnerDay?> watchDay(PartnerLink link, String date);
}
