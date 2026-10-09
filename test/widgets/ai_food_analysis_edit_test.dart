import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/services/gemini/models/food_analysis.dart';
import 'package:sophis/ui/components/ai_food_result.dart';
import 'package:sophis/ui/components/ai_food_result_card.dart';
import 'package:sophis/ui/components/edit_food_analysis_sheet.dart';
import 'package:sophis/ui/theme/app_theme.dart';

void main() {
  EditableFoodResult createResult() => EditableFoodResult(
        analysis: FoodAnalysis(
          name: 'diced tomatoes',
          portionGrams: 150,
          calories: 27,
          protein: 1.3,
          carbs: 5.8,
          fat: 0.3,
          fiber: 1.8,
        ),
      );

  Widget app(Widget child) => MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.3),
          ),
          child: child!,
        ),
        home: Scaffold(body: child),
      );

  testWidgets('submitted a description without editing estimated values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final result = createResult();
    addTearDown(result.dispose);
    String? correction;
    await tester.pumpWidget(
      app(
        EditFoodAnalysisSheet(
          result: result,
          remainingRequests: 15,
          onSaveEdits: () {},
          onReAnalyze: (hint) => correction = hint,
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('ai-correction-description')),
      '2 tomatoes',
    );
    await tester.tap(find.widgetWithIcon(OutlinedButton, Icons.auto_awesome));
    await tester.pump();
    expect(correction, contains('2 tomatoes'));
    expect(correction, contains('Recalculate the portion weight and all'));
    expect(result.currentAnalysis.portionGrams, 150);
    expect(tester.takeException(), isNull);
    expect(find.widgetWithIcon(ElevatedButton, Icons.check), findsNothing);
    await tester.tap(find.text('Manuell anpassen'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.widgetWithIcon(ElevatedButton, Icons.check));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('result actions fitted narrow German screens with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final result = createResult();
    addTearDown(result.dispose);
    await tester.pumpWidget(
      app(
        AiFoodResultCard(
          result: result,
          onEdit: () {},
          onShare: () {},
          onAdd: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Hinzufügen'), findsOneWidget);
  });
}
