import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sophis/main.dart' as app;
import 'package:sophis/ui/theme/animations.dart';
import 'package:provider/provider.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/ui/screens/meal_planner_screen.dart';
import 'package:sophis/ui/screens/add_planned_meal_sheet.dart';
import 'package:sophis/ui/screens/water_screen.dart';
import 'package:sophis/ui/screens/recipes_screen.dart';
import 'package:sophis/ui/components/draft_guard.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('dexterous.com/flutter/local_notifications'),
    (call) async => call.method == 'initialize' ? true : null,
  );
  testWidgets('reviewed real simulator home, planner, water and recipe layouts', (tester) async {
    FadeInSlide.setEnabledForTesting(false);
    app.main();
    for (var i = 0; i < 150 && app.navigatorKey.currentContext == null; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(app.navigatorKey.currentContext, isNotNull);
    Future<void> capture(String name) async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      final bytes = await binding.takeScreenshot(name);
      final root = await getApplicationSupportDirectory();
      final dir = Directory('${root.path}/polish-review');
      await dir.create(recursive: true);
      await File('${dir.path}/$name.png').writeAsBytes(bytes);
      expect(tester.takeException(), isNull);
    }
    await tester.pump(const Duration(seconds: 2));
    final settings = app.navigatorKey.currentContext!.read<SettingsProvider>();
    await settings.setLocale('de');
    await settings.completeOnboarding();
    await tester.pump(const Duration(seconds: 2));
    await capture('home');
    final navigator = app.navigatorKey.currentState!;
    for (final screen in <String, Widget>{'planner': const MealPlannerScreen(), 'water': const WaterScreen(), 'recipes': const RecipesScreen()}.entries) {
      navigator.push(MaterialPageRoute<void>(builder: (_) => screen.value));
      await capture(screen.key);
      navigator.pop();
      await tester.pump(const Duration(seconds: 1));
    }
    showDraftBottomSheet<void>(context: app.navigatorKey.currentContext!, builder: (_) => AddPlannedMealSheet(date: DateTime.now()));
    await capture('planner-add');
    tester.widget<TabBar>(find.byType(TabBar)).controller!.animateTo(3);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(TextFormField).first);
    await capture('planner-focused');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 1));
    navigator.pop();
    await tester.pump(const Duration(seconds: 1));
  });
}
