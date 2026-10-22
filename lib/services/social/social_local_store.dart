import 'dart:convert';

import 'package:drift/drift.dart';

/// Social data has its own database, never the private nutrition outbox.
/// Pass a NativeDatabase executor in the application, or an in-memory executor
/// in tests. Opening this store requires no Firebase initialization.
final class SocialLocalStore extends GeneratedDatabase {
  SocialLocalStore(super.executor);
  int _transitionVersion = 0;
  int get transitionVersion => _transitionVersion;

  @override
  int get schemaVersion => 3;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) await _createPartnerProjection();
          if (from < 3) await _createPartnerCache();
        },
        onCreate: (migrator) async {
          await _createPartnerCache();
          await _createPartnerProjection();
          await customStatement('''
            CREATE TABLE social_session (
              singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
              account_id TEXT, generation INTEGER NOT NULL
            )
          ''');
          await customStatement(
            'INSERT INTO social_session VALUES (1, NULL, 0)',
          );
          await customStatement('''
            CREATE TABLE social_commands (
              operation_id TEXT PRIMARY KEY, account_id TEXT NOT NULL,
              generation INTEGER NOT NULL, action TEXT NOT NULL,
              target_id TEXT NOT NULL, payload TEXT NOT NULL,
              created_at INTEGER NOT NULL, attempts INTEGER NOT NULL DEFAULT 0,
              next_attempt_at INTEGER NOT NULL DEFAULT 0,
              status TEXT NOT NULL DEFAULT 'queued'
            )
          ''');
          await customStatement('''
            CREATE TABLE social_cache (
              id TEXT PRIMARY KEY, payload TEXT NOT NULL,
              cached_at INTEGER NOT NULL, position INTEGER NOT NULL
            )
          ''');
        },
      );

  Future<void> _createPartnerCache() => customStatement('''
    CREATE TABLE social_partner_cache (
      id TEXT PRIMARY KEY, connection_id TEXT, connection_state TEXT,
      payload TEXT NOT NULL, cached_at INTEGER NOT NULL
    )
  ''');

  Future<String?> _cachedConnectionState(String connectionId) async {
    final row = await customSelect(
      "SELECT payload FROM social_partner_cache WHERE id = 'partners'",
    ).getSingleOrNull();
    if (row == null) return null;
    final connections =
        (jsonDecode(row.read<String>('payload')) as Map)['connections'] as List;
    for (final raw in connections) {
      final connection = raw as Map;
      if (connection['id'] == connectionId &&
          connection['status'] == 'accepted') {
        return jsonEncode(connection);
      }
    }
    return null;
  }

  Future<String?> cachedConnectionState(SocialSession expected, String id) =>
      transaction(() async {
        if (!await isCurrent(expected)) return null;
        return _cachedConnectionState(id);
      });

  Future<SocialCachedResponse?> partnerCache(
    SocialSession expected,
    String key,
  ) =>
      transaction(() async {
        if (expected.accountId == null || !await isCurrent(expected)) {
          return null;
        }
        final row = await customSelect(
          'SELECT * FROM social_partner_cache WHERE id = ?',
          variables: [Variable(key)],
        ).getSingleOrNull();
        if (row == null) return null;
        final connection = row.readNullable<String>('connection_id');
        if (connection != null &&
            await _cachedConnectionState(connection) !=
                row.readNullable<String>('connection_state')) {
          return null;
        }
        return SocialCachedResponse(
          jsonDecode(row.read<String>('payload')) as Map<String, dynamic>,
          DateTime.fromMillisecondsSinceEpoch(row.read<int>('cached_at')),
        );
      });

  Future<void> cachePartnerResponse(
    SocialSession expected,
    String key,
    Map<String, dynamic> data, {
    String? connectionId,
    String? connectionState,
  }) =>
      transaction(() async {
        if (expected.accountId == null || !await isCurrent(expected)) return;
        if (connectionId != null &&
            (connectionState == null ||
                await _cachedConnectionState(connectionId) !=
                    connectionState)) {
          return;
        }
        await customStatement(
          'INSERT OR REPLACE INTO social_partner_cache VALUES (?, ?, ?, ?, ?)',
          [
            key,
            connectionId,
            connectionState,
            jsonEncode(data),
            DateTime.now().millisecondsSinceEpoch,
          ],
        );
        if (key == 'partners') {
          final rows = await customSelect(
            'SELECT id, connection_id, connection_state FROM social_partner_cache WHERE connection_id IS NOT NULL',
          ).get();
          for (final row in rows) {
            if (await _cachedConnectionState(
                  row.read<String>('connection_id'),
                ) !=
                row.readNullable<String>('connection_state')) {
              await customStatement(
                'DELETE FROM social_partner_cache WHERE id = ?',
                [row.read<String>('id')],
              );
            }
          }
        }
        // Keep profile/connections and a bounded set of recent day/page responses.
        await customStatement(
          'DELETE FROM social_partner_cache WHERE connection_id IS NOT NULL AND id NOT IN (SELECT id FROM social_partner_cache WHERE connection_id IS NOT NULL ORDER BY cached_at DESC, id LIMIT 100)',
        );
      });

  Future<void> clearPartnerCache(
    SocialSession expected, {
    String? connectionId,
  }) =>
      transaction(() async {
        if (!await isCurrent(expected)) return;
        if (connectionId == null) {
          await customStatement('DELETE FROM social_partner_cache');
        } else {
          await customStatement(
            'DELETE FROM social_partner_cache WHERE connection_id = ?',
            [connectionId],
          );
          final cached = await partnerCache(expected, 'partners');
          if (cached != null) {
            final data = {
              ...cached.data,
              'connections': (cached.data['connections'] as List)
                  .where((raw) => (raw as Map)['id'] != connectionId)
                  .toList(),
            };
            await cachePartnerResponse(expected, 'partners', data);
          }
        }
      });

  Future<void> _createPartnerProjection() => customStatement(
        'CREATE TABLE social_partner_projection (id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
      );

  Future<Map<String, dynamic>> partnerProjection(
    SocialSession expected,
    String key,
  ) async {
    if (!await isCurrent(expected)) return {};
    final row = await customSelect(
      'SELECT payload FROM social_partner_projection WHERE id = ?',
      variables: [Variable(key)],
    ).getSingleOrNull();
    return row == null
        ? {}
        : jsonDecode(row.read<String>('payload')) as Map<String, dynamic>;
  }

  /// Queue intent and its projection receipt commit together. No private outbox
  /// records are read or copied by this account-scoped store.
  Future<bool> recordPartnerProjection(
    SocialSession expected,
    String key,
    Map<String, dynamic> state, {
    SocialQueuedCommand? command,
  }) =>
      transaction(() async {
        if (!await isCurrent(expected)) return false;
        if (command != null) await enqueue(expected, command);
        await customStatement(
          'INSERT OR REPLACE INTO social_partner_projection VALUES (?, ?)',
          [key, jsonEncode(state)],
        );
        return true;
      });

  Future<void> cancelPartnerUpdates(
    SocialSession expected,
    String connectionId,
  ) =>
      transaction(() async {
        if (!await isCurrent(expected)) return;
        final rows = await customSelect(
          "SELECT operation_id, target_id, action, payload FROM social_commands WHERE action IN ('syncPartnerMeal', 'syncPartnerContribution', 'syncPartnerGoals')",
        ).get();
        for (final row in rows) {
          final payload = jsonDecode(row.read<String>('payload')) as Map;
          if (payload['connectionId'] == connectionId) {
            final target = row.read<String>('target_id');
            final key = target.substring(0, target.lastIndexOf(':'));
            if (row.read<String>('action') != 'syncPartnerGoals') {
              await customStatement(
                'DELETE FROM social_partner_projection WHERE id = ?',
                [key],
              );
            }
            await customStatement(
              'DELETE FROM social_commands WHERE operation_id = ?',
              [row.read<String>('operation_id')],
            );
          }
        }
      });

  /// Refresh invalidates stale upload intents before the projection rebuilds
  /// them under current consent. Privacy removals are always retained.
  Future<void> reconcilePartnerUpdates(
    SocialSession expected,
    Map<String, int> revisions,
  ) =>
      transaction(() async {
        if (!await isCurrent(expected)) return;
        final rows = await customSelect(
          "SELECT payload FROM social_commands WHERE action IN ('syncPartnerMeal', 'syncPartnerContribution', 'syncPartnerGoals')",
        ).get();
        final stale = <String>{};
        for (final row in rows) {
          final payload =
              jsonDecode(row.read<String>('payload')) as Map<String, dynamic>;
          final id = payload['connectionId'] as String;
          if (revisions[id] != payload['consentRevision']) stale.add(id);
        }
        for (final id in stale) {
          await cancelPartnerUpdates(expected, id);
        }
        // An explicit refresh/app resume retries pending valid-session work;
        // automatic queue drains still stop on the first failure.
        await customStatement(
          "UPDATE social_commands SET status = 'queued', next_attempt_at = 0 WHERE status IN ('review', 'queued') AND action IN ('syncPartnerMeal', 'syncPartnerContribution', 'syncPartnerGoals', 'deletePartnerSource')",
        );
      });

  Future<Map<String, int>> partnerQueueStatus(SocialSession expected) =>
      transaction(() async {
        if (!await isCurrent(expected)) return {};
        final rows = await customSelect(
          "SELECT status, COUNT(*) AS amount FROM social_commands WHERE action IN ('syncPartnerMeal', 'syncPartnerContribution', 'syncPartnerGoals', 'deletePartnerSource') GROUP BY status",
        ).get();
        return {
          for (final row in rows)
            row.read<String>('status'): row.read<int>('amount'),
        };
      });

  Future<void> retirePublishing() => transaction(() async {
        await customStatement(
          "DELETE FROM social_commands WHERE action IN ('publish', 'editPost', 'react')",
        );
        await customStatement('DELETE FROM social_cache');
      });

  Future<SocialSession> session() async {
    final row = await customSelect(
      'SELECT account_id, generation FROM social_session WHERE singleton = 1',
    ).getSingle();
    return SocialSession(
      accountId: row.readNullable<String>('account_id'),
      generation: row.read<int>('generation'),
    );
  }

  /// Called for every sign-out/account switch, even when switching back to the
  /// same account. One transaction invalidates pending work and removes caches.
  Future<SocialSession> switchAccount(String? accountId) {
    // Invalidate captures synchronously, before asynchronous SQLite work starts.
    _transitionVersion++;
    return transaction(() async {
      await customStatement('DELETE FROM social_commands');
      await customStatement('DELETE FROM social_cache');
      await customStatement('DELETE FROM social_partner_projection');
      await customStatement('DELETE FROM social_partner_cache');
      await customStatement(
        'UPDATE social_session SET account_id = ?, generation = generation + 1 WHERE singleton = 1',
        [accountId],
      );
      return session();
    });
  }

  Future<bool> isCurrent(SocialSession expected) async {
    final current = await session();
    return current.accountId == expected.accountId &&
        current.generation == expected.generation;
  }

  Future<void> enqueue(SocialSession expected, SocialQueuedCommand command) =>
      transaction(() async {
        if (expected.accountId == null || !await isCurrent(expected)) {
          throw StateError('Social account changed');
        }
        final existing = await customSelect(
          'SELECT action FROM social_commands WHERE target_id = ? AND action = ?',
          variables: [Variable(command.targetId), const Variable('deletePost')],
        ).get();
        if (existing.isNotEmpty && command.action != 'deletePost') return;
        if (command.action == 'deletePost') {
          await customStatement(
            'DELETE FROM social_commands WHERE target_id = ? AND action IN (?, ?)',
            [command.targetId, 'publish', 'editPost'],
          );
        }
        await customStatement('''
          INSERT INTO social_commands
            (operation_id, account_id, generation, action, target_id, payload, created_at)
          VALUES (?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(operation_id) DO NOTHING
        ''', [
          command.operationId,
          expected.accountId,
          expected.generation,
          command.action,
          command.targetId,
          jsonEncode(command.payload),
          command.createdAt.millisecondsSinceEpoch,
        ]);
      });

  Future<SocialQueuedCommand?> nextCommand(
    SocialSession expected,
    DateTime now,
  ) =>
      transaction(() async {
        if (expected.accountId == null || !await isCurrent(expected)) {
          return null;
        }
        final rows = await customSelect(
          '''
          SELECT * FROM social_commands
          WHERE account_id = ? AND generation = ? AND status = 'queued'
            AND next_attempt_at <= ?
          ORDER BY CASE WHEN action IN ('deletePost', 'deletePartnerSource') THEN 0 ELSE 1 END,
            created_at, operation_id
          LIMIT 1
        ''',
          variables: [
            Variable(expected.accountId!),
            Variable(expected.generation),
            Variable(now.millisecondsSinceEpoch),
          ],
        ).get();
        if (rows.isEmpty) return null;
        final row = rows.single;
        return SocialQueuedCommand(
          operationId: row.read<String>('operation_id'),
          action: row.read<String>('action'),
          targetId: row.read<String>('target_id'),
          payload:
              jsonDecode(row.read<String>('payload')) as Map<String, dynamic>,
          createdAt:
              DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
          attempts: row.read<int>('attempts'),
        );
      });

  Future<String?> pendingPublicationOperation(
    SocialSession expected,
    String postId,
  ) =>
      transaction(() async {
        if (!await isCurrent(expected)) return null;
        final rows = await customSelect(
          "SELECT operation_id FROM social_commands WHERE target_id = ? AND action = 'publish' LIMIT 1",
          variables: [Variable(postId)],
        ).get();
        return rows.isEmpty ? null : rows.single.read<String>('operation_id');
      });

  Future<Set<String>> pendingDeletionTargets(SocialSession expected) =>
      transaction(() async {
        if (expected.accountId == null || !await isCurrent(expected)) return {};
        final rows = await customSelect(
          'SELECT target_id FROM social_commands WHERE action = ? AND account_id = ? AND generation = ?',
          variables: [
            const Variable('deletePost'),
            Variable(expected.accountId!),
            Variable(expected.generation),
          ],
        ).get();
        return rows.map((row) => row.read<String>('target_id')).toSet();
      });

  Future<void> acknowledge(SocialSession expected, String operationId) async {
    await customStatement(
      '''
      DELETE FROM social_commands
      WHERE operation_id = ? AND account_id = ? AND generation = ?
    ''',
      [operationId, expected.accountId, expected.generation],
    );
  }

  Future<void> retry(
    SocialSession expected,
    SocialQueuedCommand command,
    DateTime now, {
    bool requiresReview = false,
  }) async {
    final attempts = command.attempts + 1;
    final seconds = attempts < 10 ? 1 << attempts : 1024;
    await customStatement('''
      UPDATE social_commands SET attempts = ?, next_attempt_at = ?, status = ?
      WHERE operation_id = ? AND account_id = ? AND generation = ?
    ''', [
      attempts,
      now.add(Duration(seconds: seconds)).millisecondsSinceEpoch,
      requiresReview ? 'review' : 'queued',
      command.operationId,
      expected.accountId,
      expected.generation,
    ]);
  }

  /// Replaces a bounded cache only after rechecking the original account epoch.
  Future<void> cacheFeed(
    SocialSession expected,
    List<Map<String, dynamic>> posts,
    DateTime now,
  ) =>
      transaction(() async {
        if (expected.accountId == null || !await isCurrent(expected)) return;
        await customStatement('DELETE FROM social_cache');
        var position = 0;
        for (final post in posts.take(100)) {
          await customStatement(
            'INSERT INTO social_cache (id, payload, cached_at, position) VALUES (?, ?, ?, ?)',
            [
              post['id'],
              jsonEncode(post),
              now.millisecondsSinceEpoch,
              position++,
            ],
          );
        }
      });

  Future<List<Map<String, dynamic>>> cachedFeed(SocialSession expected) =>
      transaction(() async {
        if (expected.accountId == null || !await isCurrent(expected)) return [];
        final rows = await customSelect(
          'SELECT payload FROM social_cache ORDER BY position LIMIT 100',
        ).get();
        return rows
            .map(
              (row) => jsonDecode(row.read<String>('payload'))
                  as Map<String, dynamic>,
            )
            .toList();
      });

  /// Invoke when a server refresh detects removal/block, and before presenting
  /// cached data after relationship changes. Imports are separate local copies.
  Future<void> clearCache({SocialSession? expected}) => transaction(() async {
        if (expected != null && !await isCurrent(expected)) return;
        await customStatement('DELETE FROM social_cache');
      });
}

final class SocialSession {
  final String? accountId;
  final int generation;

  const SocialSession({required this.accountId, required this.generation});
}

final class SocialQueuedCommand {
  final String operationId;
  final String action;
  final String targetId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;

  SocialQueuedCommand({
    required this.operationId,
    required this.action,
    required this.targetId,
    required Map<String, dynamic> payload,
    required this.createdAt,
    this.attempts = 0,
  }) : payload = Map.unmodifiable(payload) {
    if (![
      'publish',
      'editPost',
      'deletePost',
      'react',
      'syncPartnerGoals',
      'syncPartnerMeal',
      'syncPartnerContribution',
      'deletePartnerSource',
    ].contains(action)) {
      throw ArgumentError('Unsupported queued social action');
    }
    if (payload.containsKey('accountId') ||
        payload.containsKey('authorId') ||
        payload.containsKey('action')) {
      throw ArgumentError('Identity and action belong to the transport');
    }
  }
}

final class SocialCachedResponse {
  final Map<String, dynamic> data;
  final DateTime savedAt;
  const SocialCachedResponse(this.data, this.savedAt);
}
