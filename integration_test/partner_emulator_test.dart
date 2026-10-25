import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/partner_day.dart';
import 'package:sophis/services/partner/firebase_partner_backend.dart';
import 'package:sophis/services/partner/partner_backend.dart';

/// Runs the real Firebase backend against local emulators:
/// cd backend && firebase emulators:start --project demo-sophis --only auth,firestore
/// flutter test integration_test/partner_emulator_test.dart \
///   --dart-define=PARTNER_EMULATOR_HOST=127.0.0.1
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const host = String.fromEnvironment('PARTNER_EMULATOR_HOST');

  testWidgets(
    'paired two accounts, shared a day and disconnected',
    (tester) async {
      final backend = await FirebasePartnerBackend.open();
      final run = DateTime.now().millisecondsSinceEpoch;
      final alice = 'alice$run@example.test';
      final bob = 'bob$run@example.test';
      final today = PartnerDay.key(DateTime.now());

      await backend.createAccount(alice, 'password1');
      await backend.saveName('Alice');
      final invite = await backend.createInvite();
      await backend.signOut();

      await backend.createAccount(bob, 'password1');
      await backend.saveName('Bob');
      await expectLater(
        backend.acceptInvite('ZZZZ2222'),
        throwsA(isA<PartnerException>()),
      );
      await backend.acceptInvite(invite.code);
      final bobProfile = await backend.watchProfile().first;
      final bobLink = await backend.link(bobProfile!.connectionId!);
      expect(bobLink.partnerName, 'Alice');
      await backend.writeDay(
        bobLink.connectionId,
        PartnerDay(
          date: today,
          goals: NutritionGoals(calories: 2200),
          burned: 100,
          entries: [
            FoodEntry(
              id: 'pasta',
              name: 'Pasta',
              calories: 700,
              protein: 25,
              carbs: 110,
              fat: 15,
              timestamp: DateTime.now(),
              meal: 'dinner',
            ),
          ],
        ),
      );
      await backend.signOut();

      await backend.signIn(alice, 'password1');
      final aliceProfile = await backend.watchProfile().first;
      final aliceLink = await backend.link(aliceProfile!.connectionId!);
      expect(aliceLink.partnerName, 'Bob');
      final bobDay = await backend
          .watchDay(aliceLink, today)
          .firstWhere((day) => day != null);
      expect(bobDay!.entries.single.name, 'Pasta');
      expect(bobDay.remainingCalories, 1600);
      await expectLater(
        backend.createInvite(),
        throwsA(
          isA<PartnerException>()
              .having((e) => e.error, 'error', PartnerError.alreadyPaired),
        ),
      );

      await backend.disconnect(aliceLink);
      expect((await backend.watchProfile().first)!.connectionId, isNull);
      await backend.deleteAccount(null);
    },
    skip: host.isEmpty,
  );
}
