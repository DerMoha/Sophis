import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/ui/components/organic/progress.dart';
import 'package:sophis/ui/theme/app_theme.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('RadialProgress', () {
    testWidgets('rendered without crashing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 100,
            height: 100,
            child: RadialProgress(
              value: 0.5,
              size: 80,
              strokeWidth: 6,
              color: AppTheme.protein,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RadialProgress), findsOneWidget);
    });

    testWidgets('clamped negative value did not crash', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RadialProgress(
            value: -0.5,
            size: 60,
            strokeWidth: 4,
            color: AppTheme.carbs,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RadialProgress), findsOneWidget);
    });

    testWidgets('clamped value above 1 did not crash', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RadialProgress(
            value: 2.5,
            size: 60,
            strokeWidth: 4,
            color: AppTheme.fat,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RadialProgress), findsOneWidget);
    });

    testWidgets('animated from 0 to target value', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RadialProgress(
            value: 0.8,
            size: 80,
            strokeWidth: 6,
            color: AppTheme.protein,
          ),
        ),
      );

      // First frame: animation at 0
      await tester.pump();
      // Let the 800ms easeOutCubic animation complete
      await tester.pumpAndSettle(const Duration(milliseconds: 800));
      expect(find.byType(RadialProgress), findsOneWidget);
    });

    testWidgets('supported gradient color', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RadialProgress(
            value: 0.5,
            size: 80,
            strokeWidth: 6,
            gradient: LinearGradient(
              colors: [AppTheme.protein, AppTheme.fiber],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RadialProgress), findsOneWidget);
    });

    testWidgets('showGlow rendered without crashing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RadialProgress(
            value: 0.5,
            size: 80,
            strokeWidth: 6,
            color: AppTheme.protein,
            showGlow: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RadialProgress), findsOneWidget);
    });

    testWidgets('disabled glow rendered without crashing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const RadialProgress(
            value: 0.5,
            size: 80,
            strokeWidth: 6,
            color: AppTheme.protein,
            showGlow: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RadialProgress), findsOneWidget);
    });
  });
}
