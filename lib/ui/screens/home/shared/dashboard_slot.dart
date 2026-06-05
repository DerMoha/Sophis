import 'package:flutter/material.dart';

import 'package:sophis/l10n/generated/app_localizations.dart';
import 'package:sophis/models/app_settings.dart';
import 'package:sophis/models/custom_meal_type.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/nutrition_totals.dart';
import 'package:sophis/ui/components/organic/utility.dart';
import 'package:sophis/ui/components/progress_photos_dashboard_card.dart';
import 'package:sophis/ui/components/streak_card.dart';
import 'package:sophis/ui/components/supplements_today_card.dart';
import 'package:sophis/ui/screens/home/modern/widgets/widgets.dart';
import 'package:sophis/ui/screens/home/shared/home_actions.dart';
import 'package:sophis/ui/theme/animations.dart';

/// A single element of the home dashboard, decided by the [HomeDashboardVM].
/// The parent screen just maps each slot to a widget; visibility, ordering,
/// and inter-slot spacing all live in the VM.
///
/// Sealed so we get exhaustive pattern matching in `_renderSlot`.
sealed class DashboardSlot {
  const DashboardSlot();
}

/// Vertical breathing room. A slot of pure space, never animated, never tapped.
class DashboardSpace extends DashboardSlot {
  final double height;
  const DashboardSpace(this.height);
}

/// The calorie hero card. Always present when goals are set.
class DashboardCalorieHero extends DashboardSlot {
  final double consumed;
  final double baseGoal;
  final double effectiveGoal;
  final double remaining;
  final double progress;
  final double burnedCalories;

  const DashboardCalorieHero({
    required this.consumed,
    required this.baseGoal,
    required this.effectiveGoal,
    required this.remaining,
    required this.progress,
    required this.burnedCalories,
  });
}

/// Streak card. Only present when [UserStats.currentStreak] >= 2.
class DashboardStreak extends DashboardSlot {
  const DashboardStreak();
}

/// Macro rings row. Always present when goals are set.
class DashboardMacros extends DashboardSlot {
  final NutritionTotals totals;
  final NutritionGoals goals;
  const DashboardMacros({required this.totals, required this.goals});
}

/// Water tracking card. Always present when goals are set.
class DashboardWater extends DashboardSlot {
  final double waterTotal;
  final double waterGoal;
  final UnitSystem unitSystem;
  const DashboardWater({
    required this.waterTotal,
    required this.waterGoal,
    required this.unitSystem,
  });
}

/// Progress photos card. Always present.
class DashboardProgressPhotos extends DashboardSlot {
  const DashboardProgressPhotos();
}

/// Supplements card. Only present when settings.showSupplements == true.
class DashboardSupplements extends DashboardSlot {
  const DashboardSupplements();
}

/// Section header for the meal list ("Today" with restaurant icon).
class DashboardMealHeader extends DashboardSlot {
  const DashboardMealHeader();
}

/// One meal section. One slot per configured meal type, in order.
class DashboardMealSection extends DashboardSlot {
  final CustomMealType mealType;
  final bool showMacros;
  const DashboardMealSection({required this.mealType, required this.showMacros});
}

/// Quick actions grid. Only present when there is at least one visible action.
class DashboardQuickActions extends DashboardSlot {
  final List<HomeAction> actions;
  final QuickActionSize size;
  const DashboardQuickActions({required this.actions, required this.size});
}

/// Renders a [DashboardSlot] to a widget. Exposed for tests and the screen.
Widget renderDashboardSlot(
  BuildContext context,
  DashboardSlot slot, {
  required int fadeIndex,
}) {
  return switch (slot) {
    DashboardSpace(:final height) => SizedBox(height: height),
    DashboardCalorieHero(
      :final consumed,
      :final baseGoal,
      :final effectiveGoal,
      :final remaining,
      :final progress,
      :final burnedCalories,
    ) =>
      FadeInSlide(
        index: fadeIndex,
        child: CalorieHeroCard(
          consumed: consumed,
          baseGoal: baseGoal,
          effectiveGoal: effectiveGoal,
          remaining: remaining,
          progress: progress,
          burnedCalories: burnedCalories,
        ),
      ),
    DashboardStreak() => FadeInSlide(
        index: fadeIndex,
        child: const StreakCard(),
      ),
    DashboardMacros(:final totals, :final goals) => FadeInSlide(
        index: fadeIndex,
        child: MacrosCard(totals: totals, goals: goals),
      ),
    DashboardWater(
      :final waterTotal,
      :final waterGoal,
      :final unitSystem,
    ) =>
      FadeInSlide(
        index: fadeIndex,
        child: WaterCard(
          waterTotal: waterTotal,
          waterGoal: waterGoal,
          unitSystem: unitSystem,
        ),
      ),
    DashboardProgressPhotos() => FadeInSlide(
        index: fadeIndex,
        child: const ProgressPhotosDashboardCard(),
      ),
    DashboardSupplements() => FadeInSlide(
        index: fadeIndex,
        child: const SupplementsTodayCard(),
      ),
    DashboardMealHeader() => Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          return FadeInSlide(
            index: fadeIndex,
            child: SectionHeader(
              title: l10n.today,
              icon: Icons.restaurant_outlined,
            ),
          );
        },
      ),
    DashboardMealSection(:final mealType, :final showMacros) => FadeInSlide(
        index: fadeIndex,
        child: MealSection(
          mealType: mealType.id,
          title: mealType.name,
          icon: mealType.icon,
          color: mealType.color,
          showMacros: showMacros,
        ),
      ),
    DashboardQuickActions(:final actions, :final size) => FadeInSlide(
        index: fadeIndex,
        child: QuickActionsSection(actions: actions, size: size),
      ),
  };
}

/// Computes the list of fade-animated widgets from a slot list. The screen
/// delegates ordering and visibility to the VM; this just turns the list
/// into widgets. Spaces never get a fade index.
List<Widget> dashboardSlotsToWidgets(
  BuildContext context,
  List<DashboardSlot> slots,
) {
  final widgets = <Widget>[];
  var fadeIndex = 0;
  for (final slot in slots) {
    if (slot is DashboardSpace) {
      widgets.add(SizedBox(height: slot.height));
    } else {
      widgets.add(
        renderDashboardSlot(context, slot, fadeIndex: fadeIndex),
      );
      fadeIndex += 1;
    }
  }
  return widgets;
}

/// Trivial section header used by the "Today" divider in the home dashboard.
/// The actual `SectionHeader` widget lives in `lib/ui/components/organic/utility.dart`;
/// this slot just wraps the call so the VM does not need to import the
/// organic-utility file directly.
