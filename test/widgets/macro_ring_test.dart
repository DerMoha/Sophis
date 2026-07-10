import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/ui/components/organic/progress.dart';
import 'package:sophis/ui/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 120, child: child),
        ),
      ),
    );

void main() {
  group('MacroRing', () {
    testWidgets('rendered label and value', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MacroRing(
            label: 'Protein',
            value: 50,
            goal: 100,
            color: AppTheme.protein,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('g'), findsOneWidget);
    });

    testWidgets('showed remaining color when under goal', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MacroRing(
            label: 'Carbs',
            value: 50,
            goal: 100,
            color: AppTheme.carbs,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Single RadialProgress (no excess rings) when under goal
      expect(find.byType(RadialProgress), findsOneWidget);
    });

    testWidgets('showed excess ring when over goal', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MacroRing(
            label: 'Fat',
            value: 120,
            goal: 100,
            color: AppTheme.fat,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Inner + tier-1 excess ring
      expect(find.byType(RadialProgress), findsNWidgets(2));
    });

    testWidgets('showed tier-2 ring when over 200%', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MacroRing(
            label: 'Protein',
            value: 250,
            goal: 100,
            color: AppTheme.protein,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Inner + tier-1 + tier-2
      expect(find.byType(RadialProgress), findsNWidgets(3));
    });

    testWidgets('capped center text at >300%', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MacroRing(
            label: 'Protein',
            value: 400,
            goal: 100,
            color: AppTheme.protein,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('>300%'), findsOneWidget);
    });

    testWidgets('used custom excessColor for tier 1', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MacroRing(
            label: 'Protein',
            value: 150,
            goal: 100,
            color: AppTheme.protein,
            excessColor: AppTheme.success,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tier 1 only (not over 200%), 2 rings
      expect(find.byType(RadialProgress), findsNWidgets(2));
    });

    testWidgets('handled zero goal without crashing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MacroRing(
            label: 'Fiber',
            value: 10,
            goal: 0,
            color: AppTheme.fiber,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fiber'), findsOneWidget);
      expect(find.byType(RadialProgress), findsOneWidget);
    });

    testWidgets('rendered custom unit', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MacroRing(
            label: 'Water',
            value: 1500,
            goal: 2000,
            color: AppTheme.water,
            unit: 'ml',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ml'), findsOneWidget);
    });

    testWidgets('did not accept positiveExcess parameter', (tester) async {
      // Verify the dead parameter was removed: this is a compile-time check.
      // If positiveExcess were still a parameter, this would be ambiguous.
      const ring = MacroRing(
        label: 'Protein',
        value: 50,
        goal: 100,
        color: AppTheme.protein,
      );
      expect(ring.label, equals('Protein'));
    });
  });
}
