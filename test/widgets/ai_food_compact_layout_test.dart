import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/services/gemini/models/food_analysis.dart';
import 'package:sophis/ui/components/ai_food_result.dart';
import 'package:sophis/ui/components/ai_food_result_card.dart';
import 'package:sophis/ui/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in {
      'Plus Jakarta Sans': 'assets/fonts/PlusJakartaSans-Variable.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('compact AI comment retained text and actions at scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final result = EditableFoodResult(
        analysis: FoodAnalysis(
          name: 'Cheese Spring Rolls / Cigara Borek',
          portionGrams: 100,
          calories: 310,
          protein: 9,
          carbs: 32,
          fat: 16,
          fiber: 2,
        ),
      );
      addTearDown(result.dispose);
      var adds = 0;
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,),
          home: RepaintBoundary(
            key: capture,
            child: Scaffold(
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    AiFoodResultCard(
                      result: result,
                      allowComments: true,
                      onEdit: () {},
                      onShare: () {},
                      onAdd: () => adds++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (Platform.environment['SOPHIS_CAPTURE_POLISH'] == '1') {
        await tester.runAsync(() async {
          final boundary = capture.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('/tmp/sophis-ai-collapsed-$scale.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Hinweise & Nährwerte'));
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      if (scale == 1) {
        expect(tester.getSize(field).height, lessThanOrEqualTo(56));
      }
      await tester.enterText(field, 'Davon hatte ich nichts');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(result.commentController.text, 'Davon hatte ich nichts');
      final add = find.widgetWithText(ElevatedButton, 'Hinzufügen');
      await tester.ensureVisible(add);
      await tester.tap(add);
      expect(adds, 1);
      expect(tester.takeException(), isNull);
      if (Platform.environment['SOPHIS_CAPTURE_POLISH'] == '1') {
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary = capture.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('/tmp/sophis-ai-compact-$scale.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
