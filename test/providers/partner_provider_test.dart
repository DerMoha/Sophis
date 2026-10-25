import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/partner_day.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/partner_provider.dart';
import 'package:sophis/services/partner/partner_backend.dart';

import '../helpers/fake_partner_backend.dart';
import '../helpers/test_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NutritionProvider nutrition;
  late FakePartnerBackend backend;
  late PartnerProvider partner;

  FoodEntry food(String id, DateTime time, {double calories = 300}) =>
      FoodEntry(
        id: id,
        name: id,
        calories: calories,
        protein: 10,
        carbs: 30,
        fat: 5,
        timestamp: time,
        meal: 'lunch',
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);
  Future<void> waitForSync() =>
      Future<void>.delayed(const Duration(milliseconds: 900));

  Future<void> pair() async {
    backend.emitAuth('me');
    await settle();
    backend.emitProfile(
      const PartnerProfile(displayName: 'Me', connectionId: 'c1'),
    );
    await settle();
    await settle();
  }

  setUp(() async {
    nutrition = await createLoadedNutritionProvider();
    backend = FakePartnerBackend();
    partner = PartnerProvider(
      nutrition: nutrition,
      open: () async => backend,
      supported: true,
    );
    await partner.start();
  });

  tearDown(() => partner.dispose());

  group('PartnerProvider', () {
    test('was signed out without an account', () async {
      backend.emitAuth(null);
      await settle();

      expect(partner.status, PartnerStatus.signedOut);
    });

    test('asked for a name after the first sign-in', () async {
      backend.emitAuth('me');
      await settle();
      backend.emitProfile(null);
      await settle();

      expect(partner.status, PartnerStatus.needsName);
    });

    test('was single with a profile but no connection', () async {
      backend.emitAuth('me');
      await settle();
      backend.emitProfile(const PartnerProfile(displayName: 'Me'));
      await settle();

      expect(partner.status, PartnerStatus.single);
      expect(partner.link, isNull);
    });

    test('shared the last seven days and skipped unchanged ones', () async {
      final now = DateTime.now();
      await nutrition.setGoals(NutritionGoals(calories: 2000));
      await nutrition.addFoodEntry(food('today', now));
      await nutrition.addFoodEntry(
        food('yesterday', DateTime(now.year, now.month, now.day - 1, 12)),
      );

      await pair();
      await settle();

      expect(partner.status, PartnerStatus.paired);
      expect(partner.link!.partnerName, 'Lena');
      expect(backend.writeCount, PartnerProvider.sharedDays);
      final today = backend.written[PartnerDay.key(now)]!;
      expect(today.entries.single.id, 'today');
      expect(today.goals!.calories, 2000);

      await nutrition.addFoodEntry(food('snack', now, calories: 150));
      await waitForSync();

      expect(backend.writeCount, PartnerProvider.sharedDays + 1);
      expect(
        backend.written[PartnerDay.key(now)]!.entries.map((e) => e.id),
        containsAll(['today', 'snack']),
      );
    });

    test("showed the partner's today live", () async {
      await pair();
      final key = PartnerDay.key(DateTime.now());

      backend.emitPartnerDay(
        key,
        PartnerDay(
          date: key,
          goals: NutritionGoals(calories: 1800),
          burned: 0,
          entries: [food('oats', DateTime.now(), calories: 400)],
        ),
      );
      await settle();

      expect(partner.partnerToday!.remainingCalories, 1400);
    });

    test('became single again when the partner disconnected', () async {
      await pair();
      backend.emitProfile(const PartnerProfile(displayName: 'Me'));
      await settle();

      expect(partner.status, PartnerStatus.single);
      expect(partner.link, isNull);
      expect(partner.partnerToday, isNull);
    });

    test('reported a failed invite and cleared it again', () async {
      backend.emitAuth('me');
      await settle();
      backend.failNext = PartnerError.inviteInvalid;

      expect(await partner.acceptInvite('ABCD2345'), isFalse);
      expect(partner.error, PartnerError.inviteInvalid);

      partner.clearError();
      expect(partner.error, isNull);
    });

    test('kept a created invite for sharing', () async {
      backend.emitAuth('me');
      await settle();

      expect(await partner.createInvite(), isTrue);
      expect(partner.invite!.code, 'ABCD2345');
    });
  });
}
