import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/ui/components/modal_sheet.dart';
import 'package:sophis/ui/screens/recipes_screen.dart';
import 'package:sophis/ui/screens/weight_tracker_screen.dart';
import 'package:sophis/ui/screens/water_screen.dart';
import 'package:sophis/ui/components/workout_bottom_sheet.dart';
import 'package:sophis/ui/theme/app_theme.dart';

import '../helpers/test_services.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('sheet header stayed readable at large German text ($dark)',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
              viewInsets: EdgeInsets.only(bottom: 240),
            ),
            child: Scaffold(
              body: ModalSheetSurface(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ModalSheetHandle(),
                    ModalSheetHeader(title: 'Nährwertangaben bearbeiten'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Schließen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final screen in <Widget>[
    const RecipesScreen(),
    const WeightTrackerScreen(),
    const WaterScreen(),
    const Scaffold(body: WorkoutBottomSheet()),
  ]) {
    testWidgets(
        'small German layout supported large text in ${screen.runtimeType}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final nutrition = await createLoadedWidgetNutritionProvider(tester);
      final settings = await createWidgetTestSettingsProvider(tester);
      await pumpTestApp(
        tester,
        screen,
        nutritionProvider: nutrition,
        settingsProvider: settings,
        locale: const Locale('de'),
        textScaler: const TextScaler.linear(2),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
