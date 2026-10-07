import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/social/social_snapshot.dart';
import 'package:sophis/services/nutrition/nutrition_store.dart';
import 'package:sophis/services/social/social_local_store.dart';
import 'package:sophis/services/social/social_partner_repository.dart';

/// Projects only explicitly consented facts from the logging-origin ledger.
/// The private nutrition outbox, user profile and health records are never read.
final class PartnerProjection {
  final SocialLocalStore store;
  PartnerProjection(this.store);

  Future<bool> project({
    required SocialSession session,
    required PartnerConnection connection,
    required NutritionStore nutrition,
    required NutritionGoals? goals,
    required String timeZone,
  }) async {
    if (!connection.accepted || !await store.isCurrent(session)) return false;
    final settings = connection.ownSettings;
    final revision = settings['revision'] as int;
    final checkpointKey = '${connection.id}:$revision';
    final checkpoint = await store.partnerProjection(session, checkpointKey);
    final changes = await nutrition.foodSharingChanges(
      afterSequence: checkpoint['sequence'] as int? ?? 0,
    );
    for (final change in changes) {
      for (final kind in ['meals', 'summaries']) {
        final generation =
            settings[kind == 'meals' ? 'mealGeneration' : 'summaryGeneration']
                as int;
        final key = '${connection.id}:$kind:$generation:${change.foodId}';
        final receipt = await store.partnerProjection(session, key);
        if (change.deleted) {
          if (receipt.isNotEmpty && receipt['deleted'] != true) {
            await _queue(
                session,
                connection,
                key,
                {'deleted': true},
                'deletePartnerSource',
                {
                  'sourceMealId': change.foodId,
                  'sourceRevision': change.revision,
                });
          }
          continue;
        }
        if (settings[kind] != true ||
            settings['paused'] == true ||
            change.entry == null ||
            change.originallyLoggedAt == null) {
          continue;
        }
        final periods =
            (settings[kind == 'meals' ? 'mealPeriods' : 'summaryPeriods']
                    as List)
                .cast<Map<String, dynamic>>();
        if (periods.isEmpty || periods.last['end'] != null) continue;
        final start = periods.last['start'] as num;
        final logged = change.originallyLoggedAt!.millisecondsSinceEpoch;
        final eligible = periods.any(
          (period) =>
              logged >= (period['start'] as num) &&
              (period['end'] == null || logged < (period['end'] as num)),
        );
        if (!eligible ||
            change.changedAt.millisecondsSinceEpoch < start ||
            (logged < start && receipt.isEmpty) ||
            receipt['revision'] == change.revision) {
          continue;
        }
        final entry = change.entry!;
        final payload = <String, dynamic>{
          'sourceMealId': entry.id,
          'sourceRevision': change.revision,
          'originallyLoggedAt': logged,
          'changedAt': change.changedAt.millisecondsSinceEpoch,
          'localDate':
              DateFormat('yyyy-MM-dd').format(entry.timestamp.toLocal()),
          'timeZone': timeZone,
          'consentRevision': revision,
          if (kind == 'meals')
            'snapshot': SocialSnapshot.fromEntries([entry], title: entry.name)
                .toJson(nutritionVisible: true)
          else ...{
            'calories': entry.calories,
            'protein': entry.protein,
            'carbs': entry.carbs,
            'fat': entry.fat,
          },
        };
        await _queue(
          session,
          connection,
          key,
          {'revision': change.revision},
          kind == 'meals' ? 'syncPartnerMeal' : 'syncPartnerContribution',
          payload,
        );
      }
    }
    if (changes.isNotEmpty) {
      await store.recordPartnerProjection(
        session,
        checkpointKey,
        {'sequence': changes.last.sequence},
      );
    }
    if (settings['goals'] != true || settings['paused'] == true) {
      return changes.length == 100;
    }
    final payload = <String, dynamic>{
      'consentRevision': revision,
      'goals': goals == null
          ? null
          : {
              'calories': goals.calories,
              'protein': goals.protein,
              'carbs': goals.carbs,
              'fat': goals.fat,
            },
      'localDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'timeZone': timeZone,
    };
    final signature = jsonEncode(payload);
    final key = '${connection.id}:goals';
    final receipt = await store.partnerProjection(session, key);
    if (receipt['signature'] == signature) return changes.length == 100;
    final sourceRevision = (receipt['sourceRevision'] as int? ??
            DateTime.now().millisecondsSinceEpoch) +
        1;
    await _queue(
      session,
      connection,
      key,
      {'signature': signature, 'sourceRevision': sourceRevision},
      'syncPartnerGoals',
      {...payload, 'sourceRevision': sourceRevision},
    );
    return changes.length == 100;
  }

  Future<void> _queue(
    SocialSession session,
    PartnerConnection connection,
    String key,
    Map<String, dynamic> receipt,
    String action,
    Map<String, dynamic> payload,
  ) async {
    final body = {'connectionId': connection.id, ...payload};
    final operation = sha256
        .convert(utf8.encode('$key:$action:${jsonEncode(body)}'))
        .toString();
    await store.recordPartnerProjection(
      session,
      key,
      receipt,
      command: SocialQueuedCommand(
        operationId: operation,
        action: action,
        targetId: '$key:$action',
        payload: body,
        createdAt: DateTime.now(),
      ),
    );
  }
}
