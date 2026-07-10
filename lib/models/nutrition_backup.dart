import 'package:sophis/models/custom_portion.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/meal_plan.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/progress_photo.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/models/user_profile.dart';
import 'package:sophis/models/user_stats.dart';
import 'package:sophis/models/water_entry.dart';
import 'package:sophis/models/weight_entry.dart';
import 'package:sophis/models/workout_entry.dart';

/// Complete nutrition-owned state used by backup and transactional restore.
class NutritionBackup {
  final NutritionGoals? goals;
  final UserProfile? profile;
  final List<FoodEntry> foodEntries;
  final List<WaterEntry> waterEntries;
  final List<WeightEntry> weightEntries;
  final List<WorkoutEntry> workoutEntries;
  final List<Recipe> recipes;
  final List<PlannedMeal> plannedMeals;
  final List<FoodItem> customFoods;
  final List<FoodItem> favoriteFoods;
  final List<CustomPortion> customPortions;
  final List<FoodItem> recentFoods;
  final Map<String, String> recentFoodMeals;
  final UserStats userStats;
  final Set<String> shoppingListChecked;
  final List<ProgressPhoto> progressPhotos;

  const NutritionBackup({
    required this.goals,
    required this.profile,
    required this.foodEntries,
    required this.waterEntries,
    required this.weightEntries,
    required this.workoutEntries,
    required this.recipes,
    required this.plannedMeals,
    required this.customFoods,
    required this.favoriteFoods,
    required this.customPortions,
    required this.recentFoods,
    required this.recentFoodMeals,
    required this.userStats,
    required this.shoppingListChecked,
    required this.progressPhotos,
  });

  NutritionBackup copyWith({List<ProgressPhoto>? progressPhotos}) =>
      NutritionBackup(
        goals: goals,
        profile: profile,
        foodEntries: foodEntries,
        waterEntries: waterEntries,
        weightEntries: weightEntries,
        workoutEntries: workoutEntries,
        recipes: recipes,
        plannedMeals: plannedMeals,
        customFoods: customFoods,
        favoriteFoods: favoriteFoods,
        customPortions: customPortions,
        recentFoods: recentFoods,
        recentFoodMeals: recentFoodMeals,
        userStats: userStats,
        shoppingListChecked: shoppingListChecked,
        progressPhotos: progressPhotos ?? this.progressPhotos,
      );
}
