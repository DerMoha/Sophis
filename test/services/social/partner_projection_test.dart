import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/services/nutrition/nutrition_store.dart';
import 'package:sophis/services/social/partner_projection.dart';
import 'package:sophis/services/social/social_local_store.dart';
import 'package:sophis/services/social/social_partner_repository.dart';

import '../../helpers/test_services.dart';

void main() {
  late NutritionStore nutrition;
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
      sourceFoodId: 'private-food-id',);
  PartnerConnection connection(
          {bool meals = false,
          bool summaries = false,
          bool goals = false,
          bool paused = false,
          int revision = 1,
          List<Map<String, dynamic>>? periods,}) =>
      PartnerConnection.fromJson(
        {
          'id': 'connection',
          'displayName': 'Partner',
          'participants': ['alice', 'bob'],
          'inviterId': 'alice',
          'status': 'accepted',
          'settings': {
            'alice': {
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
  Future<void> project(PartnerConnection connection,
      {NutritionGoals? goals,}) async {
    await PartnerProjection(social).project(
        session: session,
        connection: connection,
        nutrition: nutrition,
        goals: goals,
        timeZone: 'Europe/Berlin',);
  }

  Future<List<SocialQueuedCommand>> drain() async {
    final commands = <SocialQueuedCommand>[];
    while (true) {
      final command = await social.nextCommand(
          session, DateTime.now().add(const Duration(days: 1)),);
      if (command == null) return commands;
      commands.add(command);
      await social.acknowledge(session, command.operationId);
    }
  }

  setUp(() async {
    now = start.subtract(const Duration(hours: 1));
    nutrition = NutritionStore(createTestDatabase(), await createTestStorage(),
        clock: () => now,);
    social = SocialLocalStore(NativeDatabase.memory());
    session = await social.switchAccount('alice');
  });
  tearDown(() async {
    await nutrition.close();
    await social.close();
  });

  test('shared and updated the author meal category without repeating unchanged work', () async {
    now = start.add(const Duration(minutes: 1));
    await nutrition.commit(SaveFoodEntry(entry('food')));
    await project(connection(meals: true));
    expect((await drain()).single.payload['mealCategory'], 'lunch');
    await project(connection(meals: true));
    expect(await drain(), isEmpty);
    await nutrition.commit(SaveFoodEntry(entry('food').copyWith(meal: 'dinner')));
    await project(connection(meals: true));
    expect((await drain()).single.payload['mealCategory'], 'dinner');
  });

  test('shared goals separately without diary, fiber or profile fields',
      () async {
    await nutrition.commit(SaveFoodEntry(entry('private')));
    await project(connection(goals: true),
        goals: NutritionGoals(
            calories: 2000, protein: 120, carbs: 250, fat: 70, fiber: 30,),);
    final command = (await drain()).single;
    expect(command.action, 'syncPartnerGoals');
    expect((command.payload['goals'] as Map).keys,
        unorderedEquals(['calories', 'protein', 'carbs', 'fat']),);
    expect(command.payload.toString(), isNot(contains('private')));
    await project(connection(goals: true),
        goals: NutritionGoals(
            calories: 2000, protein: 120, carbs: 250, fat: 70, fiber: 30,),);
    expect(await drain(), isEmpty);
  });
  test('excluded historical entries and summary-only meal details', () async {
    await nutrition.commit(SaveFoodEntry(entry('before')));
    now = start.add(const Duration(minutes: 1));
    await nutrition.commit(SaveFoodEntry(entry('after')));
    await project(connection(summaries: true));
    final command = (await drain()).single;
    expect(command.action, 'syncPartnerContribution');
    expect(command.payload['sourceMealId'], 'after');
    expect(command.payload['calories'], 100);
    expect(command.payload.containsKey('snapshot'), isFalse);
    expect(command.payload.containsKey('sourceFoodId'), isFalse);
    await project(connection(summaries: true));
    expect(await drain(), isEmpty);
  });
  test(
      'excluded paused logs after resume but delivered source deletion while paused',
      () async {
    now = start.add(const Duration(minutes: 1));
    await nutrition.commit(SaveFoodEntry(entry('shared')));
    await project(connection(meals: true));
    expect(await drain(), hasLength(1));
    final pause = now.add(const Duration(minutes: 1));
    now = pause.add(const Duration(minutes: 1));
    await nutrition.commit(SaveFoodEntry(entry('paused')));
    await nutrition.commit(const DeleteFoodEntry('shared'));
    await project(connection(meals: true, paused: true, revision: 2));
    expect((await drain()).single.action, 'deletePartnerSource');
    final resume = now.add(const Duration(minutes: 1));
    now = resume.add(const Duration(minutes: 1));
    await nutrition.commit(SaveFoodEntry(entry('resumed')));
    await project(connection(meals: true, revision: 3, periods: [
      {
        'start': start.millisecondsSinceEpoch,
        'end': pause.millisecondsSinceEpoch,
      },
      {'start': resume.millisecondsSinceEpoch, 'end': null},
    ],),);
    final command = (await drain()).single;
    expect(command.payload['sourceMealId'], 'resumed');
    expect((command.payload['snapshot'] as Map).toString(),
        isNot(contains('private-food-id')),);
  });
  test('cleared projection receipts and rejected old-account work on switching',
      () async {
    await project(connection(goals: true),
        goals: NutritionGoals(calories: 2000),);
    await social.switchAccount('bob');
    expect(
        await social.partnerProjection(
            await social.session(), 'connection:goals',),
        isEmpty,);
    await project(connection(goals: true),
        goals: NutritionGoals(calories: 2100),);
    expect(await social.nextCommand(await social.session(), DateTime.now()),
        isNull,);
  });
  test('reprojected cancelled undelivered entries under fresh consent', () async {
    now = start.add(const Duration(minutes: 1));
    await nutrition.commit(SaveFoodEntry(entry('queued')));
    await project(connection(meals: true));
    await social.cancelPartnerUpdates(session, 'connection');
    await project(connection(meals: true, summaries: true, revision: 2));
    final commands = await drain();
    expect(commands.map((command) => command.action), unorderedEquals(['syncPartnerMeal', 'syncPartnerContribution']));
    expect(commands.every((command) => command.payload['consentRevision'] == 2), isTrue);
  });

}
