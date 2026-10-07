import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/ui/screens/social/social_visuals.dart';
import 'package:sophis/ui/theme/app_theme.dart';

void main() {
  testWidgets('kept unshared progress unknown rather than showing zero',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
            body: PartnerTodayCard(progressShared: false, goals: {
          'calories': 2200,
          'protein': 130,
          'carbs': 260,
          'fat': 75,
        },),),),);
    await tester.pumpAndSettle();
    expect(find.text('Calories: — / 2200 kcal'), findsOneWidget);
    expect(find.text('Protein: — / 130 g'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });
  for (final dark in [false, true]) {
    testWidgets(
        'laid out partner graphs with large text on a narrow ${dark ? 'dark' : 'light'} screen',
        (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: const MediaQuery(
              data: MediaQueryData(
                  size: Size(320, 1000), textScaler: TextScaler.linear(2),),
              child: Scaffold(
                  body: SingleChildScrollView(
                      child: PartnerTodayCard(
                          progressShared: true,
                          goals: {
                            'calories': 2200,
                            'protein': 130,
                            'carbs': 260,
                            'fat': 75,
                          },
                          summary: {
                            'calories': 2400,
                            'protein': 150,
                            'carbs': 300,
                            'fat': 80,
                          },
                          dateLabel: '2026-10-07 · Europe/Berlin',),),),),),);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Calories: 2400 / 2200 kcal'), findsOneWidget);
    });
  }
}
