import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/app_settings.dart';
import 'package:sophis/models/custom_meal_type.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/nutrition_totals.dart';
import 'package:sophis/models/user_stats.dart';
import 'package:sophis/ui/screens/home/shared/dashboard_slot.dart';
import 'package:sophis/ui/screens/home/shared/home_dashboard_vm.dart';

void main() {
  group('HomeDashboardVM', () {
    test('hasVisibleStreak is false when streak < 2', () {
      final vm = HomeDashboardVM(
        totals: NutritionTotals.zero,
        goals: NutritionGoals(calories: 2000),
        remaining: 0,
        burnedCalories: 0,
        effectiveGoal: 2000,
        calorieProgress: 0,
        waterTotal: 0,
        waterGoal: 2000,
        unitSystem: UnitSystem.metric,
        mealTypes: [],
        showMealMacros: false,
        healthSyncEnabled: false,
        visibleDashboardCards: [],
        quickActionSize: QuickActionSize.small,
        userStats: const UserStats(currentStreak: 1),
        showSupplements: true,
      );

      expect(vm.hasVisibleStreak, isFalse);
    });

    test('hasVisibleStreak is true when streak >= 2', () {
      final vm = HomeDashboardVM(
        totals: NutritionTotals.zero,
        goals: NutritionGoals(calories: 2000),
        remaining: 0,
        burnedCalories: 0,
        effectiveGoal: 2000,
        calorieProgress: 0,
        waterTotal: 0,
        waterGoal: 2000,
        unitSystem: UnitSystem.metric,
        mealTypes: [],
        showMealMacros: false,
        healthSyncEnabled: false,
        visibleDashboardCards: [],
        quickActionSize: QuickActionSize.small,
        userStats: const UserStats(currentStreak: 2),
        showSupplements: true,
      );

      expect(vm.hasVisibleStreak, isTrue);
    });

    test('isOverGoal is true when remaining < 0', () {
      final vm = HomeDashboardVM(
        totals: NutritionTotals.zero,
        goals: NutritionGoals(calories: 2000),
        remaining: -100,
        burnedCalories: 0,
        effectiveGoal: 2000,
        calorieProgress: 0,
        waterTotal: 0,
        waterGoal: 2000,
        unitSystem: UnitSystem.metric,
        mealTypes: [],
        showMealMacros: false,
        healthSyncEnabled: false,
        visibleDashboardCards: [],
        quickActionSize: QuickActionSize.small,
        userStats: const UserStats(),
        showSupplements: true,
      );

      expect(vm.isOverGoal, isTrue);
    });
  });

  group('buildDashboardSlots', () {
    HomeDashboardVM createVm({
      int streak = 1,
      bool showSupplements = true,
      List<CustomMealType> mealTypes = const [],
    }) {
      return HomeDashboardVM(
        totals: const NutritionTotals(
          calories: 500,
          protein: 20,
          carbs: 30,
          fat: 10,
        ),
        goals: NutritionGoals(calories: 2000),
        remaining: 1500,
        burnedCalories: 0,
        effectiveGoal: 2000,
        calorieProgress: 0.25,
        waterTotal: 800,
        waterGoal: 2000,
        unitSystem: UnitSystem.metric,
        mealTypes: mealTypes,
        showMealMacros: false,
        healthSyncEnabled: false,
        visibleDashboardCards: DashboardCardIds.defaultCards,
        quickActionSize: QuickActionSize.small,
        userStats: UserStats(currentStreak: streak),
        showSupplements: showSupplements,
      );
    }

    Widget wrapApp(Widget Function(BuildContext) builder) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: builder),
      );
    }

    testWidgets('first slot is CalorieHero', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapApp((context) {
          final slots = buildDashboardSlots(context, createVm());
          return Text(slots.first is DashboardCalorieHero ? 'hero' : 'other');
        }),
      );
      expect(find.text('hero'), findsOneWidget);
    });

    testWidgets('CalorieHero carries correct consumed value',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapApp((context) {
          final slots = buildDashboardSlots(context, createVm());
          final hero = slots.whereType<DashboardCalorieHero>().first;
          return Text('${hero.consumed}');
        }),
      );
      expect(find.text('500.0'), findsOneWidget);
    });

    testWidgets('keeps streak off the focused dashboard',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapApp((context) {
          final slots = buildDashboardSlots(context, createVm(streak: 5));
          return Text(
            slots.any((s) => s is DashboardStreak) ? 'yes' : 'no',
          );
        }),
      );
      expect(find.text('no'), findsOneWidget);
    });

    testWidgets('excludes streak when streak < 2', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapApp((context) {
          final slots = buildDashboardSlots(context, createVm(streak: 1));
          return Text(
            slots.any((s) => s is DashboardStreak) ? 'yes' : 'no',
          );
        }),
      );
      expect(find.text('no'), findsOneWidget);
    });

    testWidgets('keeps supplements under More when enabled',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapApp((context) {
          final slots = buildDashboardSlots(
            context,
            createVm(showSupplements: true),
          );
          return Text(
            slots.any((s) => s is DashboardSupplements) ? 'yes' : 'no',
          );
        }),
      );
      expect(find.text('no'), findsOneWidget);
    });

    testWidgets('excludes supplements when showSupplements false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapApp((context) {
          final slots = buildDashboardSlots(
            context,
            createVm(showSupplements: false),
          );
          return Text(
            slots.any((s) => s is DashboardSupplements) ? 'yes' : 'no',
          );
        }),
      );
      expect(find.text('no'), findsOneWidget);
    });

    testWidgets('includes DashboardMealSection per mealType',
        (WidgetTester tester) async {
      final meals = <CustomMealType>[
        CustomMealType(
          id: 'breakfast',
          name: 'Breakfast',
          iconCodePoint: Icons.wb_sunny_outlined.codePoint,
          colorValue: Colors.orange.toARGB32(),
          sortOrder: 0,
        ),
        CustomMealType(
          id: 'lunch',
          name: 'Lunch',
          iconCodePoint: Icons.wb_cloudy_outlined.codePoint,
          colorValue: Colors.blue.toARGB32(),
          sortOrder: 1,
        ),
      ];
      await tester.pumpWidget(
        wrapApp((context) {
          final slots =
              buildDashboardSlots(context, createVm(mealTypes: meals));
          return Text('${slots.whereType<DashboardMealSection>().length}');
        }),
      );
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('no meal sections when mealTypes empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapApp((context) {
          final slots = buildDashboardSlots(context, createVm());
          return Text('${slots.whereType<DashboardMealSection>().length}');
        }),
      );
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('DashboardSpace between CalorieHero and Macros is 12px',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapApp((context) {
          final slots = buildDashboardSlots(context, createVm(streak: 1));
          // Index: 0=CalorieHero, 1=Space(12), 2=Macros
          final space = slots[1] as DashboardSpace;
          return Text('${space.height}');
        }),
      );
      expect(find.text('12.0'), findsOneWidget);
    });
  });

  group('dashboardSlotsToWidgets', () {
    testWidgets('converts DashboardSpace to SizedBox',
        (WidgetTester tester) async {
      final slots = <DashboardSlot>[
        const DashboardSpace(42),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final widgets = dashboardSlotsToWidgets(context, slots);
              return Column(children: widgets);
            },
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.height, 42);
    });
  });
}
