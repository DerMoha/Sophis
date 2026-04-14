import 'package:flutter/material.dart';
import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/app_settings.dart';
import 'package:sophis/ui/theme/app_theme.dart';
import 'package:sophis/ui/screens/food_diary_screen.dart';
import 'package:sophis/ui/screens/meal_planner_screen.dart';
import 'package:sophis/ui/screens/weight_tracker_screen.dart';
import 'package:sophis/ui/screens/recipes_screen.dart';
import 'package:sophis/ui/screens/activity_graph_screen.dart';
import 'package:sophis/ui/components/workout_bottom_sheet.dart';

/// Represents a home screen quick action.
class HomeAction {
  final String id;
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const HomeAction({
    required this.id,
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });
}

/// Builds the list of home actions based on visible dashboard cards.
List<HomeAction> buildHomeActions(
  BuildContext context,
  AppLocalizations l10n,
  ThemeData theme,
  List<DashboardCard> visibleCards,
) {
  return visibleCards
      .map((card) => _buildAction(context, l10n, theme, card.id))
      .where((action) => action != null)
      .cast<HomeAction>()
      .toList();
}

HomeAction? _buildAction(
  BuildContext context,
  AppLocalizations l10n,
  ThemeData theme,
  String id,
) {
  switch (id) {
    case DashboardCardIds.foodDiary:
      return HomeAction(
        id: id,
        icon: Icons.history_rounded,
        label: l10n.foodDiary,
        color: theme.colorScheme.primary,
        onTap: () => Navigator.push(
          context,
          AppTheme.slideRoute(const FoodDiaryScreen()),
        ),
      );
    case DashboardCardIds.mealPlanner:
      return HomeAction(
        id: id,
        icon: Icons.calendar_month_outlined,
        label: l10n.mealPlanner,
        onTap: () => Navigator.push(
          context,
          AppTheme.slideRoute(const MealPlannerScreen()),
        ),
      );
    case DashboardCardIds.weight:
      return HomeAction(
        id: id,
        icon: Icons.monitor_weight_outlined,
        label: l10n.weight,
        onTap: () => Navigator.push(
          context,
          AppTheme.slideRoute(const WeightTrackerScreen()),
        ),
      );
    case DashboardCardIds.recipes:
      return HomeAction(
        id: id,
        icon: Icons.menu_book_outlined,
        label: l10n.recipes,
        onTap: () => Navigator.push(
          context,
          AppTheme.slideRoute(const RecipesScreen()),
        ),
      );
    case DashboardCardIds.activity:
      return HomeAction(
        id: id,
        icon: Icons.insights_outlined,
        label: l10n.activity,
        onTap: () => Navigator.push(
          context,
          AppTheme.slideRoute(const ActivityGraphScreen()),
        ),
      );
    case DashboardCardIds.workout:
      return HomeAction(
        id: id,
        icon: Icons.local_fire_department_rounded,
        label: l10n.workout,
        color: AppTheme.fire,
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const WorkoutBottomSheet(),
        ),
      );
    default:
      return null;
  }
}
