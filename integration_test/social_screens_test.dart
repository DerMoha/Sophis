import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:sophis/main.dart' as app;
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/social_provider.dart';
import 'package:sophis/services/social/social_runtime.dart';
import 'package:sophis/ui/screens/social/people_screen.dart';

import 'social_screen_capture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Notification delivery is outside this test. Keep the native permission
  // prompt from blocking bootstrap; Firebase and SQLite remain real adapters.
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('dexterous.com/flutter/local_notifications'),
    (call) async => call.method == 'initialize' ? true : null,
  );

  Future<void> waitFor(WidgetTester tester, bool Function() condition) async {
    for (var attempt = 0; attempt < 150 && !condition(); attempt++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(condition(), isTrue);
  }

  testWidgets(
      'created an emulator account, saved profile, created and revoked an invitation and signed out without changing the diary',
      (tester) async {
    expect(
      SocialRuntime.configuration()?.options.projectId,
      'demo-sophis',
      reason: 'This test must never use production Firebase',
    );
    app.main();
    await waitFor(tester, () => app.navigatorKey.currentContext != null);
    final navigator = app.navigatorKey.currentState!;
    final nutrition =
        app.navigatorKey.currentContext!.read<NutritionProvider>();
    final before = (await nutrition.store.snapshot())
        .value
        .foodEntries
        .map((entry) => entry.toJson())
        .toList();
    navigator
        .push(MaterialPageRoute<void>(builder: (_) => const PeopleScreen()));
    await waitFor(
      tester,
      () => find.text('Create an account').evaluate().isNotEmpty,
    );
    await captureSocialScreen(binding, tester, 'people-account');
    await tester.tap(find.widgetWithText(TextButton, 'Create an account'));
    await tester.pumpAndSettle();
    final email =
        'simulator-${DateTime.now().millisecondsSinceEpoch}@example.invalid';
    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'SophisSimulator123!',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await waitFor(
      tester,
      () => find.text('Your private profile').evaluate().isNotEmpty,
    );
    await captureSocialScreen(binding, tester, 'people-profile');
    await tester.enterText(find.byType(TextField).first, 'Simulator Chef');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Save profile'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save profile'));
    await waitFor(
      tester,
      () => find.text('Your partners').evaluate().isNotEmpty,
    );
    expect(
      find.text(
        'No partner connections yet. Use Invite a partner above to connect.',
      ),
      findsOneWidget,
    );
    await captureSocialScreen(binding, tester, 'partner-list');
    await tester.tap(find.byTooltip('Invite a partner'));
    await waitFor(
      tester,
      () => find.text('Invite a partner').evaluate().isNotEmpty,
    );
    await captureSocialScreen(binding, tester, 'people-connections');
    await tester.tap(find.widgetWithText(FilledButton, 'Invite a partner'));
    await waitFor(
      tester,
      () => find.text('Partner invitation').evaluate().isNotEmpty,
    );
    expect(
      find.text(
        'One person can use this invitation. It expires after 48 hours.',
      ),
      findsOneWidget,
    );
    await captureSocialScreen(binding, tester, 'people-invitation');
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Revoke'));
    await tester.tap(find.widgetWithText(TextButton, 'Revoke'));
    await waitFor(
      tester,
      () => find.text('Partner invitation').evaluate().isEmpty,
    );
    navigator.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await waitFor(
      tester,
      () =>
          app.navigatorKey.currentContext!.read<SocialProvider>().accountId ==
          null,
    );
    await captureSocialScreen(binding, tester, 'people-signed-out');
    final after = (await nutrition.store.snapshot())
        .value
        .foodEntries
        .map((entry) => entry.toJson())
        .toList();
    expect(after, before);
    expect(find.text('Cook, share, encourage'), findsOneWidget);
    expect(find.text('Your partners'), findsNothing);
  });
}
