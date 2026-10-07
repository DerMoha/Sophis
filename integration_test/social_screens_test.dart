import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sophis/main.dart' as app;
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/social_provider.dart';
import 'package:sophis/services/social/social_runtime.dart';
import 'package:sophis/ui/screens/social/people_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Notification delivery is outside this test. Keep the native permission
  // prompt from blocking bootstrap; Firebase and SQLite remain real adapters.
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('dexterous.com/flutter/local_notifications'),
    (call) async => call.method == 'initialize' ? true : null,
  );

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('SOCIAL_SCREENSHOTS')) return;
    await tester.pumpAndSettle();
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    final bytes = await binding.takeScreenshot(name);
    final directory = await getApplicationSupportDirectory();
    final screenshots = Directory('${directory.path}/social-test-screenshots');
    await screenshots.create(recursive: true);
    await File('${screenshots.path}/$name.png').writeAsBytes(bytes);
  }

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
    await capture(tester, 'people-account');
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
    await capture(tester, 'people-profile');
    await tester.enterText(find.byType(TextField).first, 'Simulator Chef');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Save profile'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save profile'));
    await waitFor(
      tester,
      () => find.text('Hello, Simulator Chef').evaluate().isNotEmpty,
    );
    expect(
      find.text(
        'No shared meals yet. Invite a friend or partner from Connections.',
      ),
      findsOneWidget,
    );
    await capture(tester, 'people-feed');
    await tester.tap(find.byTooltip('Connections'));
    await waitFor(
      tester,
      () => find.text('Invite a friend').evaluate().isNotEmpty,
    );
    await capture(tester, 'people-connections');
    await tester.tap(find.widgetWithText(FilledButton, 'Invite a friend'));
    await waitFor(
      tester,
      () => find.text('Follow invitation').evaluate().isNotEmpty,
    );
    expect(
      find.text(
        'One person can use this invitation. It expires after 48 hours.',
      ),
      findsOneWidget,
    );
    await capture(tester, 'people-invitation');
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Revoke'));
    await tester.tap(find.widgetWithText(TextButton, 'Revoke'));
    await waitFor(
      tester,
      () => find.text('Follow invitation').evaluate().isEmpty,
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
    await capture(tester, 'people-signed-out');
    final after = (await nutrition.store.snapshot())
        .value
        .foodEntries
        .map((entry) => entry.toJson())
        .toList();
    expect(after, before);
    expect(find.text('Cook, share, encourage'), findsOneWidget);
    expect(find.text('Hello, Simulator Chef'), findsNothing);
  });
}
