import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/ui/components/quick_add_sheet.dart';
import 'package:sophis/ui/screens/ai_food_camera_screen.dart';
import 'package:sophis/ui/screens/barcode_scanner_screen.dart';
import 'package:sophis/ui/screens/nutrition_label_camera_screen.dart';
import 'package:sophis/ui/screens/nutrition_label_scanner_screen.dart';

import '../helpers/test_services.dart';

void main() {
  for (final action in [
    'Food photo',
    'Barcode',
    'Nutrition label',
  ]) {
    testWidgets('opened $action from the main add choices in one tap',
        (tester) async {
      final nutrition =
          (await tester.runAsync(() => createLoadedNutritionProvider()))!;
      final settings = await createWidgetTestSettingsProvider(tester);
      // Stop before native camera initialization: this test verifies navigation,
      // while the operating system owns camera permission prompts.
      const models = MethodChannel('sophis/scan_models');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(models,
          (_) async {
        throw PlatformException(code: 'play_services_unavailable');
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(models, null),
      );
      await pumpTestApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showQuickAddSheet(context, mealType: 'dinner'),
              child: const Text('Open'),
            ),
          ),
        ),
        nutritionProvider: nutrition,
        settingsProvider: settings,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Optional AI'), findsNothing);
      expect(find.text('Scan product'), findsNothing);
      expect(find.text('Photos are sent to your selected AI provider.'), findsOneWidget);
      await tester.ensureVisible(find.text(action));
      await tester.tap(find.text(action));
      if (action == 'Nutrition label') {
        // The camera preview spinner never settles without a native camera.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      } else {
        await tester.pumpAndSettle();
      }
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      if (action == 'Food photo') {
        expect(find.byType(AIFoodCameraScreen), findsOneWidget);
        expect(
          tester
              .widget<AIFoodCameraScreen>(find.byType(AIFoodCameraScreen))
              .meal,
          'dinner',
        );
      } else if (action == 'Barcode') {
        expect(find.byType(BarcodeScannerScreen), findsOneWidget);
        expect(
          tester
              .widget<BarcodeScannerScreen>(find.byType(BarcodeScannerScreen))
              .meal,
          'dinner',
        );
      }
      if (action == 'Nutrition label') {
        // The scanner skips its intro and opens the camera straight away.
        expect(find.byType(NutritionLabelCameraScreen), findsOneWidget);
        expect(
          find.byType(NutritionLabelScannerScreen, skipOffstage: false),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
