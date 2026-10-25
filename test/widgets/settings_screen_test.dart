import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/ui/screens/settings_screen.dart';

import '../helpers/test_services.dart';

void main() {
  group('SettingsScreen', () {
    testWidgets('opened every settings page in narrow German large text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = createTestDatabase();
      addTearDown(database.close);
      final nutrition = await createLoadedWidgetNutritionProvider(
        tester,
        database: database,
      );
      final settings = await createWidgetTestSettingsProvider(tester);
      nutrition.attachSettingsProvider(settings);
      await nutrition.setGoals(NutritionGoals(calories: 2200));

      await pumpTestApp(
        tester,
        const SettingsScreen(),
        nutritionProvider: nutrition,
        settingsProvider: settings,
        locale: const Locale('de'),
        textScaler: const TextScaler.linear(2),
      );
      await tester.pumpAndSettle();

      expect(find.text('2200 kcal'), findsOneWidget);

      final l10n = lookupAppLocalizations(const Locale('de'));
      final pages = [
        l10n.settingsMeals,
        l10n.supplements,
        l10n.appearance,
        l10n.languageAndUnits,
        l10n.mealReminders,
        'Health Connect',
        l10n.aiSection,
        l10n.offAccountTitle,
        l10n.privacy,
        l10n.dataSection,
      ];
      final exceptions = <String>[];
      for (final page in pages) {
        final row = find.text(page).hitTestable();
        for (var i = 0; i < 40 && row.evaluate().isEmpty; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -120));
          await tester.pumpAndSettle();
        }
        await tester.tap(row.first);
        await tester.pumpAndSettle();
        final exception = tester.takeException();
        if (exception != null) exceptions.add('$page: $exception');
        expect(find.byType(BackButton), findsOneWidget, reason: page);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }

      expect(exceptions, isEmpty);
    });
  });
}
