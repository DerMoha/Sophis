import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sophis/providers/social_provider.dart';
import 'package:sophis/ui/screens/social/people_screen.dart';

void main() {
  testWidgets('kept guest tracking available without Firebase configuration',
      (tester) async {
    var opened = false;
    final social = SocialProvider(
      configured: false,
      factory: () async {
        opened = true;
        throw StateError('Must not initialize');
      },
    );
    addTearDown(social.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: social,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const PeopleScreen(),
                  ),
                ),
                child: const Text('Tracking'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Tracking'));
    await tester.pumpAndSettle();
    expect(opened, isFalse);
    expect(find.text('Cook, share, encourage'), findsOneWidget);
    await tester.tap(find.text('Continue tracking'));
    await tester.pumpAndSettle();
    expect(find.text('Tracking'), findsOneWidget);
  });
  testWidgets('offered a retry after optional social initialization failed',
      (tester) async {
    var attempts = 0;
    final social = SocialProvider(
      configured: true,
      factory: () async {
        attempts++;
        throw StateError('Offline');
      },
    );
    addTearDown(social.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: social,
        child: const MaterialApp(home: PeopleScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('People could not connect. Try again.'), findsOneWidget);
    expect(attempts, 1);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });
}
