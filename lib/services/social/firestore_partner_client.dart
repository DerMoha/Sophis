import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:sophis/models/social/social_snapshot.dart';
import 'package:sophis/services/service_result.dart';
import 'package:sophis/services/social/social_callable_client.dart';
import 'package:sophis/services/social/social_local_store.dart';

/// Firestore REST uses the captured user's ID token and Security Rules. There is
/// no Admin SDK, billing dependency, persistent remote cache or implicit replay.
final class FirestorePartnerClient implements SocialClient {
  final SocialCredentials credentials;
  final SocialLocalStore store;
  final http.Client httpClient;
  final String projectId;
  final String? emulatorHost;
  final int emulatorPort;
  final DateTime Function() _clock;
  final Duration credentialTimeout;
  Duration _serverClockOffset = Duration.zero;

  FirestorePartnerClient({
    required this.credentials,
    required this.store,
    required this.httpClient,
    required this.projectId,
    this.emulatorHost,
    this.emulatorPort = 8080,
    DateTime Function()? clock,
    this.credentialTimeout = const Duration(seconds: 20),
  }) : _clock = clock ?? DateTime.now {
    if (emulatorHost != null && !projectId.startsWith('demo-')) {
      throw ArgumentError('Emulators require a demo project');
    }
  }

  @override
  String? get accountId => credentials.accountId;
  int? get _epoch => credentials is SocialCredentialSession
      ? (credentials as SocialCredentialSession).authenticationVersion
      : null;
  String get _root => 'projects/$projectId/databases/(default)/documents';
  Uri _uri(String suffix) => emulatorHost == null
      ? Uri.https('firestore.googleapis.com', '/v1/$_root$suffix')
      : Uri.http('$emulatorHost:$emulatorPort', '/v1/$_root$suffix');

  @override
  Future<SocialSession?> captureSession() async {
    final uid = accountId, epoch = _epoch, transition = store.transitionVersion;
    final session = await store.session();
    return uid != null &&
            uid == accountId &&
            session.accountId == uid &&
            epoch == _epoch &&
            transition == store.transitionVersion
        ? session
        : null;
  }

  Future<void> _check(_Scope s) async {
    final current = await store.isCurrent(s.session);
    if (!current ||
        s.session.accountId == null ||
        accountId != s.session.accountId ||
        s.epoch != _epoch ||
        s.transition != store.transitionVersion) {
      throw const _RemoteFailure('UNAUTHENTICATED');
    }
  }

  Future<Object?> _request(
    _Scope s,
    String method,
    String suffix, [
    Object? body,
  ]) async {
    await _check(s);
    final tokens =
        await credentials.tokensFor(s.uid).timeout(credentialTimeout);
    await _check(s);
    if (tokens.accountId != s.uid || tokens.idToken.isEmpty) {
      throw const _RemoteFailure('UNAUTHENTICATED');
    }
    final request = http.Request(method, _uri(suffix))
      ..followRedirects = false
      ..headers.addAll({
        'Authorization': 'Bearer ${tokens.idToken}',
        'Content-Type': 'application/json',
        if (tokens.appCheckToken != null)
          'X-Firebase-AppCheck': tokens.appCheckToken!,
      });
    if (body != null) request.body = jsonEncode(body);
    await _check(s);
    final response =
        await httpClient.send(request).timeout(const Duration(seconds: 20));
    final bytes = <int>[];
    await for (final chunk
        in response.stream.timeout(const Duration(seconds: 20))) {
      bytes.addAll(chunk);
      if (bytes.length > 2 * 1024 * 1024) throw const FormatException();
    }
    await _check(s);
    if (response.statusCode >= 300) {
      Object? error;
      try {
        error = bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes));
      } on FormatException {/* Gateways may return plain text or HTML. */}
      final fallback = switch (response.statusCode) {
        401 => 'UNAUTHENTICATED',
        403 => 'PERMISSION_DENIED',
        404 => 'NOT_FOUND',
        429 => 'RESOURCE_EXHAUSTED',
        >= 500 => 'UNAVAILABLE',
        _ => 'INVALID_ARGUMENT',
      };
      throw _RemoteFailure(
        error is Map && error['error'] is Map
            ? (error['error'] as Map)['status'] as String? ?? fallback
            : fallback,
      );
    }
    final result = bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes));
    // Only fresh server timestamps can calibrate the device clock. A document's
    // updateTime may be old. Commit/read time minus receipt time is a conservative
    // offset: it never moves local food forward by an assumed network delay.
    final serverTime = result is Map
        ? result['commitTime']
        : result is List && result.isNotEmpty && result.last is Map
            ? (result.last as Map)['readTime']
            : null;
    if (serverTime is String) {
      _serverClockOffset =
          DateTime.parse(serverTime).difference(_clock().toUtc());
    }
    return result;
  }

  Future<_Document?> _get(_Scope s, String path) async {
    try {
      final data = await _request(s, 'GET', '/$path') as Map<String, dynamic>;
      return _Document(
        path,
        _fields(data['fields'] as Map? ?? {}),
        data['updateTime'] as String,
      );
    } on _RemoteFailure catch (e) {
      if (e.status == 'NOT_FOUND') return null;
      rethrow;
    }
  }

  Map<String, dynamic> _write(
    String path,
    Map<String, dynamic> data, {
    String? version,
    bool create = false,
    List<String> times = const [],
  }) =>
      {
        'update': {
          'name': '$_root/$path',
          'fields': data.map((k, v) => MapEntry(k, _encode(v))),
        },
        if (version != null) 'currentDocument': {'updateTime': version},
        if (create) 'currentDocument': {'exists': false},
        if (times.isNotEmpty)
          'updateTransforms': [
            for (final field in times)
              {'fieldPath': field, 'setToServerValue': 'REQUEST_TIME'},
          ],
      };
  Future<void> _commit(_Scope s, List<Map<String, dynamic>> writes) async {
    if (writes.isNotEmpty) {
      await _request(s, 'POST', ':commit', {'writes': writes});
    }
  }

  Future<List<_Document>> _query(
    _Scope s,
    String parent,
    String collection,
    Map<String, dynamic> equalities, {
    String? cursor,
    String? containsField,
    Object? containsValue,
  }) async {
    final filters = <Map<String, dynamic>>[
      for (final e in equalities.entries)
        if (e.value == null)
          {
            'unaryFilter': {
              'field': {'fieldPath': e.key},
              'op': 'IS_NULL',
            },
          }
        else
          {
            'fieldFilter': {
              'field': {'fieldPath': e.key},
              'op': 'EQUAL',
              'value': _encode(e.value),
            },
          },
      if (containsField != null)
        {
          'fieldFilter': {
            'field': {'fieldPath': containsField},
            'op': 'ARRAY_CONTAINS',
            'value': _encode(containsValue),
          },
        },
    ];
    final base = parent.isEmpty ? collection : '$parent/$collection';
    final result = await _request(
        s, 'POST', '${parent.isEmpty ? '' : '/$parent'}:runQuery', {
      'structuredQuery': {
        'from': [
          {'collectionId': collection},
        ],
        if (filters.isNotEmpty)
          'where': filters.length == 1
              ? filters.single
              : {
                  'compositeFilter': {'op': 'AND', 'filters': filters},
                },
        'orderBy': [
          {
            'field': {'fieldPath': '__name__'},
            'direction': 'ASCENDING',
          }
        ],
        'limit': 20,
        if (cursor != null)
          'startAt': {
            'values': [
              {'referenceValue': '$_root/$base/${_id(cursor)}'},
            ],
            'before': false,
          },
      },
    }) as List;
    final documents = <_Document>[];
    for (final raw in result) {
      final row = raw as Map<String, dynamic>;
      final document = row['document'] as Map<String, dynamic>?;
      if (document == null) continue;
      documents.add(
        _Document(
          (document['name'] as String).split('/documents/').last,
          _fields(document['fields'] as Map? ?? {}),
          document['updateTime'] as String,
        ),
      );
    }
    return documents;
  }

  @override
  Future<ServiceResult<Object?>> call(
    SocialSession expected,
    String action,
    Map<String, dynamic> payload,
  ) async {
    if (payload.keys.any(['accountId', 'authorId', 'action'].contains)) {
      return const Failure(
        ServiceErrorType.parseError,
        'Invalid partner payload.',
      );
    }
    final scope = _Scope(expected, _epoch, store.transitionVersion);
    try {
      await _check(scope);
      for (var attempt = 0;; attempt++) {
        try {
          final result = await _dispatch(scope, action, payload);
          await _check(scope);
          return Success(_public(result));
        } on _RemoteFailure catch (e) {
          if (attempt < 2 &&
              ['ABORTED', 'FAILED_PRECONDITION', 'ALREADY_EXISTS']
                  .contains(e.status)) {
            continue;
          }
          rethrow;
        }
      }
    } on _RemoteFailure catch (e) {
      return Failure(
        switch (e.status) {
          'UNAUTHENTICATED' ||
          'PERMISSION_DENIED' =>
            ServiceErrorType.authFailed,
          'NOT_FOUND' => ServiceErrorType.notFound,
          'RESOURCE_EXHAUSTED' => ServiceErrorType.rateLimited,
          'UNAVAILABLE' ||
          'DEADLINE_EXCEEDED' ||
          'ABORTED' =>
            ServiceErrorType.network,
          _ => ServiceErrorType.unknown,
        },
        switch (e.status) {
          'PERMISSION_DENIED' =>
            'Sharing permission changed, or this invitation is unavailable. Refresh and try again.',
          'RESOURCE_EXHAUSTED' =>
            'Sharing reached a service limit. Your local diary still works. Try again later.',
          'UNAUTHENTICATED' => 'Your account changed. Sign in again.',
          'NOT_FOUND' =>
            'This invitation or partner connection is unavailable.',
          _ => 'Could not complete partner sharing. Refresh and try again.',
        },
      );
    } on SocialCredentialFailure catch (e) {
      return Failure(e.errorType, 'Could not refresh your session. Try again.');
    } on TimeoutException {
      return const Failure(
        ServiceErrorType.network,
        'Partner sharing timed out. Try again.',
      );
    } on http.ClientException {
      return const Failure(
        ServiceErrorType.network,
        'Partner sharing is offline. Try again.',
      );
    } catch (_) {
      return const Failure(
        ServiceErrorType.parseError,
        'Could not read partner information.',
      );
    }
  }

  Future<Map<String, dynamic>> _dispatch(
    _Scope s,
    String action,
    Map<String, dynamic> p,
  ) async {
    final uid = s.uid;
    switch (action) {
      case 'ownProfile':
        return {'profile': (await _get(s, 'partnerProfiles/$uid'))?.data};
      case 'setProfile':
        final name = (p['displayName'] as String).trim();
        if (name.isEmpty || name.length > 60) throw const FormatException();
        final data = {'accountId': uid, 'displayName': name};
        await _commit(s, [_write('partnerProfiles/$uid', data)]);
        return data;
      case 'createInvitation':
        if (p['audience'] != 'partner') throw const FormatException();
        final profile = await _get(s, 'partnerProfiles/$uid');
        if (profile == null) throw const _RemoteFailure('NOT_FOUND');
        final random = Random.secure();
        final token = base64Url
            .encode(List.generate(32, (_) => random.nextInt(256)))
            .replaceAll('=', '');
        final expires = DateTime.now().toUtc().add(const Duration(hours: 48));
        await _commit(s, [
          _write(
            'partnerInvitations/${_hash(token)}',
            {
              'inviterId': uid,
              'displayName': profile.data['displayName'],
              'expiresAt': expires,
              'createdAt': null,
              'consumedBy': null,
              'revoked': false,
            },
            create: true,
            times: ['createdAt'],
          ),
        ]);
        return {'token': token, 'expiresAt': expires};
      case 'previewInvitation':
        final invite =
            await _get(s, 'partnerInvitations/${_tokenKey(p['token'])}');
        if (invite == null) throw const _RemoteFailure('NOT_FOUND');
        return {...invite.data, 'audience': 'partner'};
      case 'revokeInvitation':
        final path = 'partnerInvitations/${_tokenKey(p['token'])}';
        final invite = await _get(s, path);
        if (invite == null) throw const _RemoteFailure('NOT_FOUND');
        await _commit(s, [
          _write(
            path,
            {...invite.data, 'revoked': true},
            version: invite.version,
          ),
        ]);
        return {};
      case 'requestPartner':
        return _requestPartner(s, p['token']);
      case 'partners':
        final connections = <Map<String, dynamic>>[];
        String? cursor;
        for (var page = 0; page < 10; page++) {
          final docs = await _query(
            s,
            '',
            'partnerConnections',
            {},
            containsField: 'participants',
            containsValue: uid,
            cursor: cursor,
          );
          connections.addAll([
            for (final d in docs)
              if (d.data['revokedAt'] == null) _connection(d, uid),
          ]);
          if (docs.length < 20) return {'connections': connections};
          cursor = docs.last.id;
        }
        throw const _RemoteFailure('RESOURCE_EXHAUSTED');
      case 'acceptPartner':
      case 'disconnectPartner':
        final c = await _get(s, 'partnerConnections/${_id(p['connectionId'])}');
        if (c == null) throw const _RemoteFailure('NOT_FOUND');
        await _commit(s, [
          _write(
            c.path,
            {
              ...c.data,
              'status': action == 'acceptPartner' ? 'accepted' : 'revoked',
              if (action == 'disconnectPartner') 'revokedAt': null,
            },
            version: c.version,
            times: action == 'disconnectPartner' ? ['revokedAt'] : [],
          ),
        ]);
        return {};
      case 'partnerSettings':
        return _settings(s, p);
      case 'syncPartnerMeal':
        return _syncSource(s, p, meals: true);
      case 'syncPartnerContribution':
        return _syncSource(s, p, meals: false);
      case 'deletePartnerSource':
        return _deleteSource(s, p);
      case 'syncPartnerGoals':
        return _syncGoals(s, p);
      case 'partnerGoals':
        final c = await _connectionDoc(s, p);
        final other = _other(c.data, uid),
            setting = _setting(c.data, _other(c.data, uid));
        if (setting['goals'] != true) return {'goals': []};
        // Query generation so revoked snapshots are never read even momentarily.
        final docs = await _query(
          s,
          '${c.path}/members/$other',
          'goals',
          {'generation': setting['goalGeneration']},
        );
        return {
          'goals': [
            for (final d in docs)
              if (d.data['goals'] != null)
                {
                  'authorId': other,
                  ...Map<String, dynamic>.from(d.data['goals'] as Map),
                  'timeZone': d.data['timeZone'],
                },
          ],
        };
      case 'partnerMeals':
        return _meals(s, p);
      case 'partnerSummaries':
        return _summary(s, p);
      default:
        throw const _RemoteFailure('INVALID_ARGUMENT');
    }
  }

  Future<Map<String, dynamic>> _requestPartner(_Scope s, Object? token) async {
    final key = _tokenKey(token), uid = s.uid;
    final invite = await _get(s, 'partnerInvitations/$key');
    if (invite == null) throw const _RemoteFailure('NOT_FOUND');
    if (invite.data['consumedBy'] == uid) return {'id': key};
    final inviter = invite.data['inviterId'] as String;
    final profile = await _get(s, 'partnerProfiles/$uid');
    if (profile == null) throw const _RemoteFailure('NOT_FOUND');
    await _commit(s, [
      _write(
        invite.path,
        {...invite.data, 'consumedBy': uid},
        version: invite.version,
      ),
      _write(
        'partnerConnections/$key',
        {
          'participants': [inviter, uid],
          'inviterId': inviter,
          'status': 'pending',
          'revokedAt': null,
          'createdAt': null,
          'displayNames': {
            inviter: invite.data['displayName'],
            uid: profile.data['displayName'],
          },
          'settings': {inviter: _defaults(), uid: _defaults()},
        },
        create: true,
        times: ['createdAt'],
      ),
    ]);
    return {'id': key};
  }

  Future<_Document> _connectionDoc(_Scope s, Map<String, dynamic> p) async {
    final c = await _get(s, 'partnerConnections/${_id(p['connectionId'])}');
    if (c == null) throw const _RemoteFailure('NOT_FOUND');
    if (c.data['status'] != 'accepted' ||
        c.data['revokedAt'] != null ||
        !(c.data['participants'] as List).contains(s.uid)) {
      throw const _RemoteFailure('PERMISSION_DENIED');
    }
    return c;
  }

  Future<Map<String, dynamic>> _settings(
    _Scope s,
    Map<String, dynamic> p,
  ) async {
    // Compatibility for older clients: connection acceptance now enables all sharing.
    final c = await _connectionDoc(s, p);
    return {'settings': _setting(c.data, s.uid)};
  }

  Future<Map<String, dynamic>> _syncSource(
    _Scope s,
    Map<String, dynamic> p, {
    required bool meals,
  }) async {
    final c = await _connectionDoc(s, p), uid = s.uid;
    final setting = _setting(c.data, uid), prefix = meals ? 'meal' : 'summary';
    if (setting[meals ? 'meals' : 'summaries'] != true ||
        setting['paused'] == true ||
        setting['revision'] != p['consentRevision']) {
      throw const _RemoteFailure('PERMISSION_DENIED');
    }
    final path =
        '${c.path}/members/$uid/${meals ? 'meals' : 'contributions'}/${_hash(_id(p['sourceMealId']))}';
    final old = await _get(s, path);
    if (old?.data['deletedAt'] != null) return {};
    final sameGeneration =
        old != null && old.data['generation'] == setting['${prefix}Generation'];
    if (sameGeneration &&
        (old.data['sourceRevision'] as int) >= (p['sourceRevision'] as int)) {
      return {};
    }
    final localLogged = DateTime.fromMillisecondsSinceEpoch(
      (p['originallyLoggedAt'] as num).toInt(),
      isUtc: true,
    ).add(_serverClockOffset);
    // Keep the published origin immutable across edits, clock recalibration
    // and migration from the old category-permission generations.
    final logged =
        old != null ? old.data['originallyLoggedAt'] as DateTime : localLogged;
    final changed = DateTime.fromMillisecondsSinceEpoch(
      (p['changedAt'] as num).toInt(),
      isUtc: true,
    ).add(_serverClockOffset);
    final data = <String, dynamic>{
      'sourceRevision': p['sourceRevision'],
      'generation': setting['${prefix}Generation'],
      'consentRevision': setting['revision'],
      'originallyLoggedAt': logged,
      'changedAt': changed,
      'localDate': p['localDate'],
      'timeZone': p['timeZone'],
      'deletedAt': null,
      'publishedAt': old?.data['publishedAt'],
      if (meals)
        'snapshot': SocialSnapshot.fromJson(
          p['snapshot'] as Map<String, dynamic>,
          nutritionVisible: true,
        ).toJson(nutritionVisible: true),
      if (meals) 'mealCategory': p['mealCategory'] ?? 'Other',
      if (!meals)
        for (final k in ['calories', 'protein', 'carbs', 'fat']) k: p[k],
    };
    final zone = meals ? 'mealTimeZone' : 'summaryTimeZone';
    final writes = [
      _write(
        path,
        data,
        version: old?.version,
        create: old == null,
        times: old == null ? ['publishedAt'] : [],
      ),
    ];
    if (setting[zone] != p['timeZone']) {
      final all = Map<String, dynamic>.from(c.data['settings'] as Map)
        ..[uid] = {
          ...Map<String, dynamic>.from((c.data['settings'] as Map)[uid] as Map),
          zone: p['timeZone'],
        };
      writes.add(
        _write(c.path, {...c.data, 'settings': all}, version: c.version),
      );
    }
    await _commit(s, writes);
    return {};
  }

  Future<Map<String, dynamic>> _deleteSource(
    _Scope s,
    Map<String, dynamic> p,
  ) async {
    final base =
        'partnerConnections/${_id(p['connectionId'])}/members/${s.uid}';
    final key = _hash(_id(p['sourceMealId']));
    final writes = <Map<String, dynamic>>[];
    for (final collection in ['meals', 'contributions']) {
      final path = '$base/$collection/$key',
          old = await _get(s, '$base/$collection/$key');
      if (old?.data['deletedAt'] != null) continue;
      writes.add(
        _write(
          path,
          {'deletedAt': null, 'sourceRevision': p['sourceRevision']},
          version: old?.version,
          create: old == null,
          times: ['deletedAt'],
        ),
      );
    }
    await _commit(s, writes);
    return {};
  }

  Future<Map<String, dynamic>> _syncGoals(
    _Scope s,
    Map<String, dynamic> p,
  ) async {
    final c = await _connectionDoc(s, p),
        uid = s.uid,
        setting = _setting(c.data, s.uid);
    if (setting['goals'] != true ||
        setting['paused'] == true ||
        setting['revision'] != p['consentRevision']) {
      throw const _RemoteFailure('PERMISSION_DENIED');
    }
    final path = '${c.path}/members/$uid/goals/current',
        old = await _get(s, '${c.path}/members/$uid/goals/current');
    if (old != null &&
        old.data['generation'] == setting['goalGeneration'] &&
        (old.data['sourceRevision'] as int) >= (p['sourceRevision'] as int)) {
      return {};
    }
    await _commit(s, [
      _write(
        path,
        {
          'goals': p['goals'],
          'generation': setting['goalGeneration'],
          'sourceRevision': p['sourceRevision'],
          'consentRevision': p['consentRevision'],
          'timeZone': p['timeZone'],
        },
        version: old?.version,
        create: old == null,
      ),
    ]);
    return {};
  }

  Future<Map<String, dynamic>> _meals(_Scope s, Map<String, dynamic> p) async {
    final c = await _connectionDoc(s, p),
        other = _other(c.data, s.uid),
        setting = _setting(c.data, _other(c.data, s.uid));
    if (setting['meals'] != true) return {'meals': [], 'cursor': null};
    final docs = await _query(
      s,
      '${c.path}/members/$other',
      'meals',
      {
        'generation': setting['mealGeneration'],
        'localDate': p['localDate'],
        'timeZone': p['timeZone'],
        'deletedAt': null,
      },
      cursor: (p['cursor'] as Map?)?['id'] as String?,
    );
    return {
      'meals': [
        for (final d in docs) {...d.data, 'id': d.id, 'authorId': other},
      ],
      'cursor': docs.length == 20 ? {'id': docs.last.id} : null,
    };
  }

  Future<Map<String, dynamic>> _summary(
    _Scope s,
    Map<String, dynamic> p,
  ) async {
    final c = await _connectionDoc(s, p),
        other = _other(c.data, s.uid),
        setting = _setting(c.data, _other(c.data, s.uid));
    if (setting['summaries'] != true) return {'summaries': []};
    final totals = <String, dynamic>{
      'authorId': other,
      for (final k in ['calories', 'protein', 'carbs', 'fat']) k: 0.0,
    };
    String? cursor;
    for (var page = 0; page <= 10; page++) {
      final docs = await _query(
        s,
        '${c.path}/members/$other',
        'contributions',
        {
          'generation': setting['summaryGeneration'],
          'localDate': p['localDate'],
          'timeZone': p['timeZone'],
          'deletedAt': null,
        },
        cursor: cursor,
      );
      if (page == 10 && docs.isNotEmpty) {
        throw const _RemoteFailure('RESOURCE_EXHAUSTED');
      }
      for (final d in docs) {
        for (final k in ['calories', 'protein', 'carbs', 'fat']) {
          totals[k] = (totals[k] as double) + (d.data[k] as num).toDouble();
        }
      }
      if (docs.length < 20) {
        return {
          'summaries': [totals],
        };
      }
      cursor = docs.last.id;
    }
    // Never display a truncated day as a complete total.
    throw const _RemoteFailure('RESOURCE_EXHAUSTED');
  }

  @override
  Future<ServiceResult<void>> send(
    SocialSession session,
    SocialQueuedCommand command,
  ) async {
    final result = await call(session, command.action, command.payload);
    return switch (result) {
      Success<Object?>() => const Success(null),
      Failure<Object?>(:final errorType, :final message) =>
        Failure(errorType, message),
    };
  }

  Map<String, dynamic> _connection(_Document d, String uid) {
    final settings = Map<String, dynamic>.from(d.data['settings'] as Map);
    for (final id in (d.data['participants'] as List).cast<String>()) {
      final own = _setting(d.data, id);
      settings[id] = {
        ...own,
        'spark': true,
        'photos': false,
        'goalSourceRevision': 0,
        'mealPeriods': own['mealStart'] == null
            ? []
            : [
                {
                  'start': own['mealStart'],
                  'end': own['paused'] == true ? own['mealStart'] : null,
                }
              ],
        'summaryPeriods': own['summaryStart'] == null
            ? []
            : [
                {
                  'start': own['summaryStart'],
                  'end': own['paused'] == true ? own['summaryStart'] : null,
                }
              ],
      };
    }
    return {
      ...d.data,
      'id': d.id,
      'displayName': (d.data['displayNames'] as Map)[_other(d.data, uid)],
      'settings': settings,
    };
  }

  static Map<String, dynamic> _defaults() => {
        'meals': true,
        'summaries': true,
        'goals': true,
        'paused': false,
        'revision': 0,
        'mealGeneration': 0,
        'summaryGeneration': 0,
        'goalGeneration': 0,
        'mealStart': null,
        'summaryStart': null,
        'mealTimeZone': null,
        'summaryTimeZone': null,
      };
  static String _other(Map<String, dynamic> c, String uid) =>
      (c['participants'] as List).cast<String>().firstWhere((id) => id != uid);
  static Map<String, dynamic> _setting(Map<String, dynamic> c, String uid) => {
        ...Map<String, dynamic>.from((c['settings'] as Map)[uid] as Map),
        'meals': true,
        'summaries': true,
        'goals': true,
        'paused': false,
        'mealStart': DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        'summaryStart': DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      };
  static String _id(Object? v) {
    if (v is! String || v.isEmpty || v.length > 160 || v.contains('/')) {
      throw const FormatException();
    }
    return v;
  }

  static String _tokenKey(Object? v) {
    if (v is! String || !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(v)) {
      throw const FormatException();
    }
    return _hash(v);
  }

  static String _hash(String s) => sha256.convert(utf8.encode(s)).toString();
  static Map<String, dynamic> _fields(Map fields) =>
      fields.map((k, v) => MapEntry(k as String, _decode(v as Map)));
  static Object? _decode(Map v) {
    if (v.containsKey('nullValue')) return null;
    if (v.containsKey('timestampValue')) {
      return DateTime.parse(v['timestampValue'] as String).toUtc();
    }
    if (v.containsKey('integerValue')) {
      return int.parse(v['integerValue'].toString());
    }
    if (v.containsKey('doubleValue')) {
      return (v['doubleValue'] as num).toDouble();
    }
    if (v.containsKey('booleanValue')) return v['booleanValue'];
    if (v.containsKey('stringValue')) return v['stringValue'];
    if (v.containsKey('mapValue')) {
      return _fields((v['mapValue'] as Map)['fields'] as Map? ?? {});
    }
    if (v.containsKey('arrayValue')) {
      return [
        for (final e in (v['arrayValue'] as Map)['values'] as List? ?? [])
          _decode(e as Map),
      ];
    }
    throw const FormatException();
  }

  static Map<String, dynamic> _encode(Object? v) => switch (v) {
        null => {'nullValue': null},
        DateTime() => {'timestampValue': v.toUtc().toIso8601String()},
        bool() => {'booleanValue': v},
        int() => {'integerValue': '$v'},
        num() => {'doubleValue': v},
        String() => {'stringValue': v},
        List() => {
            'arrayValue': {'values': v.map(_encode).toList()},
          },
        Map() => {
            'mapValue': {
              'fields':
                  v.map((k, value) => MapEntry(k as String, _encode(value))),
            },
          },
        _ => throw const FormatException(),
      };
  static Object? _public(Object? v) => switch (v) {
        DateTime() => v.millisecondsSinceEpoch,
        List() => v.map(_public).toList(),
        Map() => <String, dynamic>{
            for (final e in v.entries) e.key as String: _public(e.value),
          },
        _ => v,
      };
}

final class _Scope {
  final SocialSession session;
  final int? epoch;
  final int transition;
  const _Scope(this.session, this.epoch, this.transition);
  String get uid => session.accountId!;
}

final class _Document {
  final String path;
  final Map<String, dynamic> data;
  final String version;
  const _Document(this.path, this.data, this.version);
  String get id => path.split('/').last;
}

final class _RemoteFailure implements Exception {
  final String status;
  const _RemoteFailure(this.status);
}
