import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/social/social_snapshot.dart';
import 'package:sophis/services/nutrition/nutrition_store.dart';
import 'package:sophis/services/social/social_local_store.dart';
import 'package:sophis/services/social/social_partner_repository.dart';

/// Projects the full food diary and nutrition goals for accepted partners.
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
    final checkpointKey = '${connection.id}:$revision:full-sharing-v1';
    final checkpoint = await store.partnerProjection(session, checkpointKey);
    final changes = await nutrition.foodSharingChanges(
      afterSequence: checkpoint['sequence'] as int? ?? 0,
      includeHistory: true,
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
        if (change.entry == null ||
            (receipt['revision'] == change.revision &&
                (kind != 'meals' ||
                    receipt['mealCategory'] == change.entry!.meal))) {
          continue;
        }
        // Older/restored entries have no logging origin. Epoch is a stable
        // transport sentinel; their meal date remains the actual diary date.
        final logged = change.originallyLoggedAt?.millisecondsSinceEpoch ?? 0;
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
          if (kind == 'meals') 'mealCategory': entry.meal,
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
          {
            'revision': change.revision,
            if (kind == 'meals') 'mealCategory': entry.meal,
          },
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
    final sourceRevision = math.max(
          receipt['sourceRevision'] as int? ??
              DateTime.now().millisecondsSinceEpoch,
          settings['goalSourceRevision'] as int? ?? 0,
        ) +
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
