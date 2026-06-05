import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/ui/components/stat_card.dart';

void main() {
  group('StatCard', () {
    testWidgets('renders icon and title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              icon: Icon(Icons.water_drop),
              iconColor: Colors.blue,
              title: Text('Water'),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.water_drop), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
    });

    testWidgets('renders iconText instead of icon widget',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              iconText: '🔥',
              title: Text('Streak'),
            ),
          ),
        ),
      );

      expect(find.text('🔥'), findsOneWidget);
      expect(find.text('Streak'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              icon: Icon(Icons.water_drop),
              title: Text('Water'),
              subtitle: Text('2.0L of 2.0L'),
            ),
          ),
        ),
      );

      expect(find.text('2.0L of 2.0L'), findsOneWidget);
    });

    testWidgets('renders trailing widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              icon: Icon(Icons.water_drop),
              title: Text('Water'),
              trailing: Text('100%'),
            ),
          ),
        ),
      );

      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('renders child body', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              icon: Icon(Icons.water_drop),
              title: Text('Water'),
              child: Text('Body content'),
            ),
          ),
        ),
      );

      expect(find.text('Body content'), findsOneWidget);
    });

    testWidgets('uses large header size when specified',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              icon: Icon(Icons.water_drop),
              title: Text('Large'),
              headerSize: StatHeaderSize.large,
            ),
          ),
        ),
      );

      expect(find.text('Large'), findsOneWidget);
    });

    testWidgets('works with no child', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              icon: Icon(Icons.water_drop),
              title: Text('Only header'),
            ),
          ),
        ),
      );

      expect(find.text('Only header'), findsOneWidget);
    });
  });
}
