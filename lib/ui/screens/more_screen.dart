import 'package:flutter/material.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/ui/components/common/app_surface.dart';
import 'package:sophis/ui/screens/activity_graph_screen.dart';
import 'package:sophis/ui/screens/meal_planner_screen.dart';
import 'package:sophis/ui/screens/progress_photo_lock_guard.dart';
import 'package:sophis/ui/screens/progress_photos_screen.dart';
import 'package:sophis/ui/screens/recipes_screen.dart';
import 'package:sophis/ui/screens/settings_screen.dart';
import 'package:sophis/ui/screens/supplements_screen.dart';
import 'package:sophis/ui/screens/water_screen.dart';
import 'package:sophis/ui/screens/weight_tracker_screen.dart';
import 'package:sophis/ui/screens/workout_screen.dart';
import 'package:sophis/ui/theme/app_theme.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, AppTheme.slideRoute(screen));
  }

  Future<void> _openProgressPhotos(BuildContext context) async {
    final unlocked = await ProgressPhotoLockGuard.requireUnlock(context);
    if (!context.mounted || !unlocked) return;
    _push(context, const ProgressPhotosScreen());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Text(l10n.more, style: theme.textTheme.headlineMedium),
              ),
            ),
            SliverPadding(
              padding: AppTheme.pagePadding,
              sliver: SliverList.list(
                children: [
                  AppSection(
                    title: l10n.planning,
                    children: [
                      AppNavigationRow(
                        title: l10n.mealPlanner,
                        icon: Icons.calendar_month_outlined,
                        onTap: () => _push(
                          context,
                          const MealPlannerScreen(),
                        ),
                      ),
                      AppNavigationRow(
                        title: l10n.recipes,
                        icon: Icons.menu_book_outlined,
                        showDivider: false,
                        onTap: () => _push(context, const RecipesScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AppSection(
                    title: l10n.tracking,
                    children: [
                      AppNavigationRow(
                        title: l10n.water,
                        icon: Icons.water_drop_outlined,
                        onTap: () => _push(context, const WaterScreen()),
                      ),
                      AppNavigationRow(
                        title: l10n.weight,
                        icon: Icons.monitor_weight_outlined,
                        onTap: () => _push(
                          context,
                          const WeightTrackerScreen(),
                        ),
                      ),
                      AppNavigationRow(
                        title: l10n.workout,
                        icon: Icons.fitness_center_outlined,
                        onTap: () => _push(context, const WorkoutScreen()),
                      ),
                      AppNavigationRow(
                        title: l10n.supplements,
                        icon: Icons.medication_outlined,
                        onTap: () => _push(
                          context,
                          const SupplementsScreen(),
                        ),
                      ),
                      AppNavigationRow(
                        title: l10n.progressPhotos,
                        icon: Icons.photo_camera_outlined,
                        onTap: () => _openProgressPhotos(context),
                      ),
                      AppNavigationRow(
                        title: l10n.insights,
                        icon: Icons.insights_outlined,
                        showDivider: false,
                        onTap: () => _push(
                          context,
                          const ActivityGraphScreen(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AppSection(
                    title: l10n.settings,
                    children: [
                      AppNavigationRow(
                        title: l10n.settings,
                        icon: Icons.settings_outlined,
                        showDivider: false,
                        onTap: () => _push(context, const SettingsScreen()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
