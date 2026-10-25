import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/services/food_intake_controller.dart';
import 'package:sophis/ui/components/portion_picker_sheet.dart';
import 'package:sophis/ui/theme/app_theme.dart';

import '../helpers/test_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry in {
      'Plus Jakarta Sans': 'assets/fonts/PlusJakartaSans-Variable.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(rootBundle.load(entry.value));
      await loader.load();
    }
  });
  for (final dark in [false, true]) {
    for (final keyboard in [0.0, 240.0]) {
      testWidgets(
          'portion sheet fit narrow large text dark=$dark keyboard=$keyboard',
          (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        addTearDown(tester.view.reset);
        final nutrition = await createLoadedWidgetNutritionProvider(tester);
        final settings = await createWidgetTestSettingsProvider(tester);
        final captureKey = GlobalKey();
        await pumpTestApp(
          tester,
          Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => Theme(
                      data: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
                      child: RepaintBoundary(
                        key: captureKey,
                        child: const PortionPickerSheet(
                          item: FoodItem(
                            id: 'oats',
                            name:
                                'Haferflocken mit Vollkorn und getrockneten Früchten',
                            category: 'food',
                            caloriesPer100g: 350,
                            proteinPer100g: 13,
                            carbsPer100g: 58,
                            fatPer100g: 7,
                          ),
                          meal: 'breakfast',
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                );
              },
            ),
          ),
          nutritionProvider: nutrition,
          settingsProvider: settings,
          foodIntakeController: FoodIntakeController(nutrition),
          locale: const Locale('de'),
          textScaler: const TextScaler.linear(2),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final slider = find.byKey(const ValueKey('portion-slider'));
        await tester.scrollUntilVisible(slider, 100,
          scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first,
        );
        await tester.pumpAndSettle();
        tester.widget<Slider>(slider).onChanged!(225);
        await tester.pumpAndSettle();
        expect(tester.widget<Slider>(slider).value, 225);
        expect(find.text('225'), findsOneWidget);
        final button = find.byType(FilledButton);
        expect(button.hitTestable(), findsOneWidget);
        expect(
          tester.getBottomLeft(button).dy,
          lessThanOrEqualTo(640 - keyboard),
        );
        await tester.scrollUntilVisible(
          find.byType(TextField),
          100,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(find.byType(TextField).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (Platform.environment['SOPHIS_CAPTURE_POLISH'] == '1') {
          await tester.runAsync(() async {
            final boundary = captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('/tmp/sophis-polish/portion-$dark-$keyboard.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
}
