import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/partner_day.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/partner_provider.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/services/partner/partner_backend.dart';
import 'package:sophis/ui/components/partner_card.dart';
import 'package:sophis/ui/screens/partner/partner_day_screen.dart';

import '../helpers/fake_partner_backend.dart';
import '../helpers/test_services.dart';

void main() {
  late NutritionProvider nutrition;
  late SettingsProvider settings;
  late FakePartnerBackend backend;
  late PartnerProvider partner;
  final today = PartnerDay.key(DateTime.now());

  PartnerDay partnerDay() => PartnerDay(
        date: today,
        goals: NutritionGoals(calories: 2000),
        burned: 0,
        entries: [
          FoodEntry(
            id: 'partner-oats',
            name: 'Oats',
            calories: 350,
            protein: 12,
            carbs: 60,
            fat: 6,
            timestamp: DateTime.now(),
            meal: 'breakfast',
          ),
          FoodEntry(
            id: 'partner-soup',
            name: 'Soup',
            calories: 250,
            protein: 8,
            carbs: 30,
            fat: 9,
            timestamp: DateTime.now(),
            meal: 'lunch',
          ),
        ],
      );

  Future<void> pumpPaired(WidgetTester tester, Widget child) async {
    nutrition = await createLoadedWidgetNutritionProvider(tester);
    settings = await createWidgetTestSettingsProvider(tester);
    nutrition.attachSettingsProvider(settings);
    backend = FakePartnerBackend();
    partner = PartnerProvider(
      nutrition: nutrition,
      open: () async => backend,
      supported: true,
    );
    addTearDown(partner.dispose);
    await partner.start();
    backend.emitAuth('me');
    await tester.pump();
    backend.emitProfile(
      const PartnerProfile(displayName: 'Me', connectionId: 'c1'),
    );
    await tester.pump();
    await tester.pump();
    await pumpTestApp(
      tester,
      Scaffold(body: child),
      nutritionProvider: nutrition,
      settingsProvider: settings,
      partnerProvider: partner,
    );
    backend.emitPartnerDay(today, partnerDay());
    await tester.pump();
    await tester.pump();
  }

  group('Partner sharing UI', () {
    testWidgets('showed what the partner has left on the home card',
        (tester) async {
      await pumpPaired(tester, const PartnerCard());

      expect(find.text('Lena'), findsOneWidget);
      expect(find.text('1,400 kcal left'), findsOneWidget);
      expect(find.text('600 of 2,000 kcal'), findsOneWidget);
    });

    testWidgets('copied a partner meal with one tap and undid it',
        (tester) async {
      await pumpPaired(tester, const PartnerDayScreen());

      expect(find.text('Oats'), findsOneWidget);
      expect(find.text('Soup'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_circle_outline_rounded).first);
      await tester.pump();
      await tester.pump();

      final copy = nutrition.entries.single;
      expect(copy.name, 'Oats');
      expect(copy.meal, 'breakfast');
      expect(copy.id, isNot('partner-oats'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Added to Breakfast'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pump();

      expect(nutrition.entries, isEmpty);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('copied a whole meal at once', (tester) async {
      await pumpPaired(tester, const PartnerDayScreen());

      await tester.tap(find.byIcon(Icons.playlist_add_rounded).last);
      await tester.pump();
      await tester.pump();

      expect(nutrition.entries.single.name, 'Soup');
      expect(nutrition.entries.single.meal, 'lunch');
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
