import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:sophis/models/partner_day.dart';
import 'package:sophis/services/partner/partner_backend.dart';

/// Firestore layout (see backend/firestore.rules):
/// - partnerProfiles/{uid}: displayName, connectionId
/// - partnerInvites/{code}: inviterId, displayName, expiresAt
/// - partnerConnections/{id}: participants, names, invite, createdAt
/// - partnerConnections/{id}/days/{uid}_{yyyy-MM-dd}: one shared diary day
final class FirebasePartnerBackend implements PartnerBackend {
  static const _emulatorHost = String.fromEnvironment('PARTNER_EMULATOR_HOST');
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Public client identifiers; Auth and Security Rules authorize access.
  /// https://firebase.google.com/docs/projects/learn-more#config-files-objects
  static FirebaseOptions? get _options => switch (defaultTargetPlatform) {
        TargetPlatform.iOS => const FirebaseOptions(
            apiKey: 'AIzaSyAP4TopMeLTPGsHlswIsl4ufrtbYYSet9Q',
            appId: '1:657623134154:ios:23417f8213e19b7d86a933',
            messagingSenderId: '657623134154',
            projectId: 'sophis-d2953',
          ),
        TargetPlatform.android => const FirebaseOptions(
            apiKey: 'AIzaSyB3M7ZLCZrgNqIq00FKjjalzWos8RIJNgc',
            appId: '1:657623134154:android:63c8bd942f9fd2d486a933',
            messagingSenderId: '657623134154',
            projectId: 'sophis-d2953',
          ),
        _ => null,
      };

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  FirebasePartnerBackend(this._auth, this._db);

  static bool get supported => _options != null;

  static Future<FirebasePartnerBackend> open() async {
    final emulator = _emulatorHost.isNotEmpty && !kReleaseMode;
    final options = emulator
        ? const FirebaseOptions(
            apiKey: 'demo-api-key',
            appId: '1:123456789:ios:0123456789abcdef',
            messagingSenderId: '123456789',
            projectId: 'demo-sophis',
          )
        : _options;
    if (options == null) throw UnsupportedError('Partner sharing platform');
    // cloud_firestore resolves its platform instance through the default app,
    // so partner sharing owns the default Firebase app.
    final existing =
        Firebase.apps.where((app) => app.name == defaultFirebaseAppName);
    final app = existing.isNotEmpty
        ? existing.first
        : await Firebase.initializeApp(options: options);
    final auth = FirebaseAuth.instanceFor(app: app);
    final db = FirebaseFirestore.instanceFor(app: app);
    if (emulator && existing.isEmpty) {
      await auth.useAuthEmulator(_emulatorHost, 19099);
      db.useFirestoreEmulator(_emulatorHost, 18080);
    }
    return FirebasePartnerBackend(auth, db);
  }

  @override
  String? get uid => _auth.currentUser?.uid;

  String get _uid {
    final id = uid;
    if (id == null) {
      throw const PartnerException(PartnerError.invalidCredentials);
    }
    return id;
  }

  DocumentReference<Map<String, dynamic>> _profile(String id) =>
      _db.doc('partnerProfiles/$id');
  DocumentReference<Map<String, dynamic>> _invite(String code) =>
      _db.doc('partnerInvites/$code');
  DocumentReference<Map<String, dynamic>> _connection(String id) =>
      _db.doc('partnerConnections/$id');
  CollectionReference<Map<String, dynamic>> _days(String connectionId) =>
      _db.collection('partnerConnections/$connectionId/days');

  @override
  Stream<String?> authChanges() => _auth.authStateChanges().map((u) => u?.uid);

  @override
  Future<void> signIn(String email, String password) => _guard(
        () => _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );

  @override
  Future<void> createAccount(String email, String password) => _guard(
        () => _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );

  @override
  Future<void> resetPassword(String email) => _guard(() async {
        try {
          await _auth.sendPasswordResetEmail(email: email.trim());
        } on FirebaseAuthException catch (error) {
          // Do not reveal whether an account exists.
          if (error.code != 'user-not-found') rethrow;
        }
      });

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  @override
  Future<void> deleteAccount(PartnerLink? link) => _guard(() async {
        final user = _auth.currentUser;
        if (user == null) return;
        if (link != null) await disconnect(link);
        await _deleteOwnInvites();
        await _profile(user.uid).delete();
        await user.delete();
      });

  @override
  Stream<PartnerProfile?> watchProfile() =>
      _profile(_uid).snapshots().map((snapshot) {
        final data = snapshot.data();
        return data == null
            ? null
            : PartnerProfile(
                displayName: data['displayName'] as String,
                connectionId: data['connectionId'] as String?,
              );
      });

  @override
  Future<void> saveName(String name) => _guard(() async {
        final reference = _profile(_uid);
        final snapshot = await reference.get();
        if (snapshot.exists) {
          await reference.update({'displayName': name.trim()});
        } else {
          await reference.set({
            'displayName': name.trim(),
            'connectionId': null,
          });
        }
      });

  @override
  Future<PartnerInvite> createInvite() => _guard(
        () async {
          final uid = _uid;
          final profile = (await _profile(uid).get()).data();
          if (profile == null) {
            throw const PartnerException(PartnerError.unknown);
          }
          if (profile['connectionId'] != null) {
            throw const PartnerException(PartnerError.alreadyPaired);
          }
          await _deleteOwnInvites();
          final random = Random.secure();
          final code = String.fromCharCodes(
            List.generate(
              8,
              (_) => _alphabet.codeUnitAt(random.nextInt(_alphabet.length)),
            ),
          );
          final expiresAt = DateTime.now().add(const Duration(hours: 24));
          await _invite(code).set({
            'inviterId': uid,
            'displayName': profile['displayName'],
            'expiresAt': Timestamp.fromDate(expiresAt),
          });
          return PartnerInvite(code: code, expiresAt: expiresAt);
        },
      );

  Future<void> _deleteOwnInvites() async {
    final own = await _db
        .collection('partnerInvites')
        .where('inviterId', isEqualTo: _uid)
        .get();
    for (final invite in own.docs) {
      await invite.reference.delete();
    }
  }

  @override
  Future<void> acceptInvite(String code) => _guard(
        () async {
          final uid = _uid;
          final invite = (await _invite(code).get()).data();
          final expiresAt = (invite?['expiresAt'] as Timestamp?)?.toDate();
          if (invite == null ||
              expiresAt == null ||
              expiresAt.isBefore(DateTime.now())) {
            throw const PartnerException(PartnerError.inviteInvalid);
          }
          final inviterId = invite['inviterId'] as String;
          if (inviterId == uid) {
            throw const PartnerException(PartnerError.ownInvite);
          }
          final profile = (await _profile(uid).get()).data();
          if (profile == null) {
            throw const PartnerException(PartnerError.unknown);
          }
          if (profile['connectionId'] != null) {
            throw const PartnerException(PartnerError.alreadyPaired);
          }
          final connection = _db.collection('partnerConnections').doc();
          final batch = _db.batch()
            ..set(connection, {
              'participants': [inviterId, uid],
              'names': {
                inviterId: invite['displayName'],
                uid: profile['displayName'],
              },
              'invite': code,
              'createdAt': FieldValue.serverTimestamp(),
            })
            ..update(_profile(inviterId), {'connectionId': connection.id})
            ..update(_profile(uid), {'connectionId': connection.id})
            ..delete(_invite(code));
          await batch.commit();
        },
        // The inviter found a partner in the meantime.
        denied: PartnerError.alreadyPaired,
      );

  @override
  Future<PartnerLink> link(String connectionId) => _guard(() async {
        final data = (await _connection(connectionId).get()).data();
        if (data == null) throw const PartnerException(PartnerError.unknown);
        final partnerId = (data['participants'] as List)
            .cast<String>()
            .firstWhere((id) => id != _uid);
        return PartnerLink(
          connectionId: connectionId,
          partnerId: partnerId,
          partnerName: (data['names'] as Map)[partnerId] as String,
        );
      });

  @override
  Future<void> disconnect(PartnerLink link) => _guard(() async {
        // Days become unreadable with the connection; delete them anyway.
        while (true) {
          final days = await _days(link.connectionId).limit(400).get();
          if (days.docs.isEmpty) break;
          final batch = _db.batch();
          for (final day in days.docs) {
            batch.delete(day.reference);
          }
          await batch.commit();
        }
        final batch = _db.batch()
          ..delete(_connection(link.connectionId))
          ..update(_profile(_uid), {'connectionId': null})
          ..update(_profile(link.partnerId), {'connectionId': null});
        await batch.commit();
      });

  @override
  Future<void> writeDay(String connectionId, PartnerDay day) =>
      _guard(() async {
        await _days(connectionId).doc('${_uid}_${day.date}').set({
          ...day.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

  @override
  Stream<PartnerDay?> watchDay(PartnerLink link, String date) => _days(
        link.connectionId,
      ).doc('${link.partnerId}_$date').snapshots().map((snapshot) {
        final data = snapshot.data();
        return data == null ? null : PartnerDay.fromJson(data);
      });

  Future<T> _guard<T>(
    Future<T> Function() operation, {
    PartnerError denied = PartnerError.unknown,
  }) async {
    try {
      return await operation();
    } on PartnerException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw PartnerException(
        switch (error.code) {
          'network-request-failed' => PartnerError.network,
          'too-many-requests' => PartnerError.tooManyRequests,
          'weak-password' => PartnerError.weakPassword,
          'invalid-email' => PartnerError.invalidEmail,
          'email-already-in-use' => PartnerError.emailInUse,
          'requires-recent-login' => PartnerError.requiresRecentLogin,
          _ => PartnerError.invalidCredentials,
        },
      );
    } on FirebaseException catch (error) {
      throw PartnerException(
        switch (error.code) {
          'unavailable' || 'deadline-exceeded' => PartnerError.network,
          'permission-denied' => denied,
          _ => PartnerError.unknown,
        },
      );
    }
  }
}
