import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/ui/components/quick_add_sheet.dart';
import 'package:sophis/ui/screens/ai_food_camera_screen.dart';
import 'package:sophis/ui/screens/barcode_scanner_screen.dart';
import 'package:sophis/ui/screens/nutrition_label_scanner_screen.dart';

import '../helpers/test_services.dart';

void main() {
  for (final action in [
    'Photograph food',
    'Scan barcode',
    'Scan Nutrition Label',
  ]) {
    testWidgets(
        'opened $action from the main add choices without an extra dialog',
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
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(models, null),);
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
      expect(
        tester.getTopLeft(find.text('Photograph food')).dy,
        lessThan(tester.getTopLeft(find.text('Scan product')).dy),
      );
      expect(find.text('Photos are sent to Google Gemini.'), findsOneWidget);
      if (action != 'Photograph food') {
        await tester.tap(find.text('Scan product'));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.textContaining(action));
      await tester.tap(find.textContaining(action));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      if (action == 'Photograph food') {
        expect(find.byType(AIFoodCameraScreen), findsOneWidget);
        expect(
            tester
                .widget<AIFoodCameraScreen>(find.byType(AIFoodCameraScreen))
                .meal,
            'dinner',);
      } else if (action == 'Scan barcode') {
        expect(find.byType(BarcodeScannerScreen), findsOneWidget);
        expect(
            tester
                .widget<BarcodeScannerScreen>(find.byType(BarcodeScannerScreen))
                .meal,
            'dinner',);
      }
      if (action == 'Scan Nutrition Label') {
        expect(find.byType(NutritionLabelScannerScreen), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
