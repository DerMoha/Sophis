import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/services/database_service.dart';
import 'package:sophis/services/nutrition/nutrition_store.dart';
import 'package:sophis/services/social/partner_projection.dart';
import 'package:sophis/services/social/social_local_store.dart';
import 'package:sophis/services/social/social_partner_repository.dart';

import '../../helpers/test_services.dart';

void main() {
  late NutritionStore nutrition;
  late DatabaseService database;
  late SocialLocalStore social;
  late SocialSession session;
  late DateTime now;
  final start = DateTime.utc(2026, 10, 7, 12);
  FoodEntry entry(String id) => FoodEntry(
        id: id,
        name: 'Rice',
        calories: 100,
        protein: 2,
        carbs: 20,
        fat: 1,
        timestamp: now,
        meal: 'lunch',
        sourceFoodId: 'private-food-id',
      );
  PartnerConnection connection({
    bool spark = false,
    bool meals = false,
    bool summaries = false,
    bool goals = false,
    bool paused = false,
    int revision = 1,
    List<Map<String, dynamic>>? periods,
  }) =>
      PartnerConnection.fromJson(
        {
          'id': 'connection',
          'displayName': 'Partner',
          'participants': ['alice', 'bob'],
          'inviterId': 'alice',
          'status': 'accepted',
          'settings': {
            'alice': {
              'spark': spark,
              'meals': meals,
              'summaries': summaries,
              'goals': goals,
              'paused': paused,
              'revision': revision,
              'mealGeneration': 0,
              'summaryGeneration': 0,
              'mealPeriods': periods ??
                  [
                    {'start': start.millisecondsSinceEpoch, 'end': null},
                  ],
              'summaryPeriods': periods ??
                  [
                    {'start': start.millisecondsSinceEpoch, 'end': null},
                  ],
            },
            'bob': {},
          },
        },
        'alice',
      );
  Future<void> project(
    PartnerConnection connection, {
    NutritionGoals? goals,
  }) async {
    await PartnerProjection(social).project(
      session: session,
      connection: connection,
      nutrition: nutrition,
      goals: goals,
      timeZone: 'Europe/Berlin',
    );
  }

  Future<List<SocialQueuedCommand>> drain() async {
    final commands = <SocialQueuedCommand>[];
    while (true) {
      final command = await social.nextCommand(
        session,
        DateTime.now().add(const Duration(days: 1)),
      );
      if (command == null) return commands;
      commands.add(command);
      await social.acknowledge(session, command.operationId);
    }
  }

  setUp(() async {
    now = start.subtract(const Duration(hours: 1));
    database = createTestDatabase();
    nutrition = NutritionStore(
      database,
      await createTestStorage(),
      clock: () => now,
    );
    social = SocialLocalStore(NativeDatabase.memory());
    session = await social.switchAccount('alice');
  });
  tearDown(() async {
    await nutrition.close();
    await social.close();
  });

  test('shared full history and goals despite legacy toggles and pauses',
      () async {
    await nutrition.commit(SaveFoodEntry(entry('before')));
    now = start.add(const Duration(minutes: 1));
    await nutrition.commit(SaveFoodEntry(entry('after')));
    await project(
      connection(paused: true),
      goals: NutritionGoals(calories: 2000),
    );
    final commands = await drain();
    expect(commands.where((c) => c.action == 'syncPartnerMeal'), hasLength(2));
    expect(
      commands.where((c) => c.action == 'syncPartnerContribution'),
      hasLength(2),
    );
    expect(commands.where((c) => c.action == 'syncPartnerGoals'), hasLength(1));
    expect(
      commands
          .where((c) => c.action == 'syncPartnerMeal')
          .map((c) => c.payload['sourceMealId']),
      unorderedEquals(['before', 'after']),
    );
    final goals = commands.singleWhere((c) => c.action == 'syncPartnerGoals');
    expect(
      (goals.payload['goals'] as Map).keys,
      unorderedEquals(['calories', 'protein', 'carbs', 'fat']),
    );
    expect(
      commands.any((c) => c.payload.toString().contains('private-food-id')),
      isFalse,
    );
    await project(
      connection(paused: true),
      goals: NutritionGoals(calories: 2000),
    );
    expect(await drain(), isEmpty);
  });

  test('shared older diary rows that had no logging-origin metadata', () async {
    await nutrition.snapshot();
    await database.upsertFood(entry('legacy'));
    await project(connection());
    final commands = await drain();
    final meal = commands.singleWhere((c) => c.action == 'syncPartnerMeal');
    expect(meal.payload['sourceMealId'], 'legacy');
    expect(meal.payload['originallyLoggedAt'], 0);
    expect(commands.where((c) => c.action == 'syncPartnerContribution'),
        hasLength(1),);
    await project(connection());
    expect(await drain(), isEmpty);
  });

  test('updated meal categories without repeating unchanged totals', () async {
    await nutrition.commit(SaveFoodEntry(entry('food')));
    await project(connection());
    await drain();
    await nutrition
        .commit(SaveFoodEntry(entry('food').copyWith(meal: 'dinner')));
    await project(connection());
    final commands = await drain();
    expect(
      commands
          .where((c) => c.action == 'syncPartnerMeal')
          .single
          .payload['mealCategory'],
      'dinner',
    );
    await project(connection());
    expect(await drain(), isEmpty);
  });

  test('removed meals and contributions even for legacy paused connections',
      () async {
    await nutrition.commit(SaveFoodEntry(entry('food')));
    await project(connection());
    await drain();
    await nutrition.commit(const DeleteFoodEntry('food'));
    await project(connection(paused: true));
    final commands = await drain();
    expect(commands, hasLength(2));
    expect(commands.every((c) => c.action == 'deletePartnerSource'), isTrue);
  });

  test('reprojected cancelled work with a fresh connection revision', () async {
    await nutrition.commit(SaveFoodEntry(entry('food')));
    await project(connection());
    await social.cancelPartnerUpdates(session, 'connection');
    await project(connection(revision: 2));
    final commands = await drain();
    expect(
      commands.map((c) => c.action),
      unorderedEquals([
        'syncPartnerMeal',
        'syncPartnerContribution',
        'syncPartnerGoals',
      ]),
    );
    expect(commands.every((c) => c.payload['consentRevision'] == 2), isTrue);
  });

  test('rejected old-account work after switching accounts', () async {
    await nutrition.commit(SaveFoodEntry(entry('food')));
    await social.switchAccount('bob');
    await project(connection());
    expect(
      await social.nextCommand(await social.session(), DateTime.now()),
      isNull,
    );
  });
}
