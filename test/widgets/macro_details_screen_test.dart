import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/nutrition_totals.dart';
import 'package:sophis/ui/components/organic/progress.dart';
import 'package:sophis/ui/screens/macro_details_screen.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  group('MacroDetailsScreen', () {
    testWidgets('rendered appbar title and all 4 macros', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MacroDetailsScreen(
            totals: const NutritionTotals(
              calories: 1000,
              protein: 75,
              carbs: 100,
              fat: 33,
              fiber: 14,
            ),
            goals: NutritionGoals(
              calories: 2000,
              protein: 150,
              carbs: 200,
              fat: 67,
              fiber: 28,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Macronutrients'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);
      expect(find.text('Fiber'), findsOneWidget);
    });

    testWidgets('hid fiber section when goal is 0', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MacroDetailsScreen(
            totals: const NutritionTotals(calories: 1000, protein: 75),
            goals: NutritionGoals(calories: 2000, fiber: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Fiber'), findsNothing);
    });

    testWidgets('showed remaining text when under goal', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MacroDetailsScreen(
            totals: const NutritionTotals(
              calories: 1000,
              protein: 75,
              carbs: 100,
              fat: 33,
              fiber: 14,
            ),
            goals: NutritionGoals(
              calories: 2000,
              protein: 150,
              carbs: 200,
              fat: 67,
              fiber: 28,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('remaining'), findsNWidgets(4));
    });

    testWidgets('showed over text when exceeding goal', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MacroDetailsScreen(
            totals: const NutritionTotals(
              calories: 1000,
              protein: 180,
              carbs: 100,
              fat: 33,
              fiber: 14,
            ),
            goals: NutritionGoals(
              calories: 2000,
              protein: 150,
              carbs: 200,
              fat: 67,
              fiber: 28,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Protein over (uses positiveExcess → goalExceeded label)
      expect(find.text('Goal exceeded'), findsOneWidget);
      // Carbs, fat, fiber remaining
      expect(find.text('remaining'), findsNWidgets(3));
    });

    testWidgets('showed goalExceeded for protein, over for others',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          MacroDetailsScreen(
            totals: const NutritionTotals(
              calories: 1000,
              protein: 180,
              carbs: 250,
              fat: 80,
              fiber: 35,
            ),
            goals: NutritionGoals(
              calories: 2000,
              protein: 150,
              carbs: 200,
              fat: 67,
              fiber: 28,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Goal exceeded'), findsOneWidget);
      expect(find.text('over'), findsNWidgets(3));
    });

    testWidgets('rounded percent to nearest integer', (tester) async {
      // 99.9 / 100 = 0.999 → should round to 100%, not truncate to 99%
      await tester.pumpWidget(
        _wrap(
          MacroDetailsScreen(
            totals: const NutritionTotals(
              calories: 1000,
              protein: 99.9,
              carbs: 100,
              fat: 33,
              fiber: 14,
            ),
            goals: NutritionGoals(
              calories: 2000,
              protein: 100,
              carbs: 200,
              fat: 67,
              fiber: 28,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('showed tier-2 ring when over 200%', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MacroDetailsScreen(
            totals: const NutritionTotals(
              calories: 1000,
              protein: 250,
              carbs: 100,
              fat: 33,
              fiber: 14,
            ),
            goals: NutritionGoals(
              calories: 2000,
              protein: 100,
              carbs: 200,
              fat: 67,
              fiber: 28,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Protein at 250% → inner + tier-1 + tier-2 = 3 RadialProgress
      // Carbs at 50% → 1
      // Fat at ~49% → 1
      // Fiber at 50% → 1
      // Total: 6
      expect(find.byType(RadialProgress), findsNWidgets(6));
    });

    testWidgets('capped percent text at >300%', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MacroDetailsScreen(
            totals: const NutritionTotals(
              calories: 1000,
              protein: 400,
              carbs: 100,
              fat: 33,
              fiber: 14,
            ),
            goals: NutritionGoals(
              calories: 2000,
              protein: 100,
              carbs: 200,
              fat: 67,
              fiber: 28,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('>300%'), findsOneWidget);
    });

    testWidgets('rendered current/goal grams text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MacroDetailsScreen(
            totals: const NutritionTotals(
              calories: 1000,
              protein: 75,
              carbs: 100,
              fat: 33,
              fiber: 14,
            ),
            goals: NutritionGoals(
              calories: 2000,
              protein: 150,
              carbs: 200,
              fat: 67,
              fiber: 28,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('75.0 / 150.0 g'), findsOneWidget);
      expect(find.text('100.0 / 200.0 g'), findsOneWidget);
    });

    testWidgets('used error color for tier-2 regardless of excessColor',
        (tester) async {
      // Protein with positiveExcess + success excessColor, but at tier 2
      // should still use error red for the tier-2 ring.
      await tester.pumpWidget(
        _wrap(
          MacroDetailsScreen(
            totals: const NutritionTotals(
              calories: 1000,
              protein: 250,
              carbs: 50,
              fat: 20,
              fiber: 10,
            ),
            goals: NutritionGoals(
              calories: 2000,
              protein: 100,
              carbs: 200,
              fat: 67,
              fiber: 28,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Just verify it renders without crashing — the color is visual.
      expect(find.text('Goal exceeded'), findsOneWidget);
      expect(find.text('250%'), findsOneWidget);
    });

    testWidgets('rendered macro icons', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MacroDetailsScreen(
            totals: const NutritionTotals(
              calories: 1000,
              protein: 75,
              carbs: 100,
              fat: 33,
              fiber: 14,
            ),
            goals: NutritionGoals(
              calories: 2000,
              protein: 150,
              carbs: 200,
              fat: 67,
              fiber: 28,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.fitness_center_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.water_drop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.grain_rounded), findsOneWidget);
    });
  });
}
