import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/nutrition_totals.dart';
import 'package:sophis/models/shareable_meal.dart';
import 'package:sophis/providers/supplements_provider.dart';
import 'package:sophis/ui/screens/activity_graph_screen.dart';
import 'package:sophis/ui/screens/add_food_screen.dart';
import 'package:sophis/ui/screens/ai_food_camera_screen.dart';
import 'package:sophis/ui/screens/dashboard_settings_screen.dart';
import 'package:sophis/ui/screens/food_diary_screen.dart';
import 'package:sophis/ui/screens/food_search_screen.dart';
import 'package:sophis/ui/screens/goals_setup_screen.dart';
import 'package:sophis/ui/screens/home/modern/home_modern_screen.dart';
import 'package:sophis/ui/screens/import_meal_screen.dart';
import 'package:sophis/ui/screens/macro_details_screen.dart';
import 'package:sophis/ui/screens/meal_detail_screen.dart';
import 'package:sophis/ui/screens/meal_macros_settings_screen.dart';
import 'package:sophis/ui/screens/meal_planner_screen.dart';
import 'package:sophis/ui/screens/meal_types_screen.dart';
import 'package:sophis/ui/screens/more_screen.dart';
import 'package:sophis/ui/screens/nutrition_label_scanner_screen.dart';
import 'package:sophis/ui/screens/onboarding_screen.dart';
import 'package:sophis/ui/screens/progress_photos_screen.dart';
import 'package:sophis/ui/screens/recipes_screen.dart';
import 'package:sophis/ui/screens/settings_screen.dart';
import 'package:sophis/ui/screens/supplements_screen.dart';
import 'package:sophis/ui/screens/water_screen.dart';
import 'package:sophis/ui/screens/weight_tracker_screen.dart';
import 'package:sophis/ui/screens/workout_screen.dart';

import '../helpers/test_services.dart';

void main() {
  testWidgets('mountable screens support narrow German large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = createTestDatabase();
    addTearDown(database.close);
    final nutrition = await createLoadedWidgetNutritionProvider(
      tester,
      database: database,
    );
    final settings = await createWidgetTestSettingsProvider(tester);
    nutrition.attachSettingsProvider(settings);
    await nutrition.setGoals(NutritionGoals(calories: 2200));
    final supplements = SupplementsProvider(
      database,
      createMockNotificationService(),
    );
    await supplements.initialize();

    final screens = <String, Widget>{
      'home': const HomeScreenModern(),
      'food diary': const FoodDiaryScreen(),
      'more': const MoreScreen(),
      'workout': const WorkoutScreen(),
      'weight tracker': const WeightTrackerScreen(),
      'meal types': const MealTypesScreen(),
      'onboarding': const OnboardingScreen(),
      'recipes': const RecipesScreen(),
      'settings': const SettingsScreen(),
      'food search': const FoodSearchScreen(meal: 'breakfast'),
      'import meal': const ImportMealScreen(
        meal: ShareableMeal(
          title: 'Breakfast',
          items: [
            SharedFoodItem(
              name: 'Oatmeal',
              calories: 700,
              protein: 45,
              carbs: 70,
              fat: 20,
              fiber: 12,
            ),
          ],
        ),
      ),
      'water': const WaterScreen(),
      'macro details': MacroDetailsScreen(
        totals: const NutritionTotals(),
        goals: NutritionGoals(calories: 2200),
      ),
      'goals setup': const GoalsSetupScreen(),
      'meal planner': const MealPlannerScreen(),
      'progress photos': const ProgressPhotosScreen(),
      'add food': const AddFoodScreen(meal: 'breakfast'),
      'supplements': ChangeNotifierProvider<SupplementsProvider>.value(
        value: supplements,
        child: const SupplementsScreen(),
      ),
      'dashboard settings': const DashboardSettingsScreen(),
      'meal detail': const MealDetailScreen(
        mealType: 'breakfast',
        mealTitle: 'Breakfast',
        mealIcon: Icons.wb_sunny_outlined,
      ),
      'meal macros settings': const MealMacrosSettingsScreen(),
      'activity graph': const ActivityGraphScreen(),
      'AI food camera': const AIFoodCameraScreen(meal: 'breakfast'),
      'nutrition label scanner': const NutritionLabelScannerScreen(
        meal: 'breakfast',
      ),
    };

    const target = String.fromEnvironment('target');
    final exceptions = <String>[];
    for (final entry in screens.entries) {
      if (target.isNotEmpty && entry.key != target) continue;
      await pumpTestApp(
        tester,
        entry.value,
        nutritionProvider: nutrition,
        settingsProvider: settings,
        locale: const Locale('de'),
        textScaler: const TextScaler.linear(2),
      );
      await tester.pump();
      final exception = tester.takeException();
      if (exception != null) exceptions.add('${entry.key}: $exception');
    }

    expect(exceptions, isEmpty);
  });
}
