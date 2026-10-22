import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/app_settings.dart';

void main() {
  test('default home shortcuts excluded duplicate diary and secondary tools',
      () {
    expect(
      DashboardCardIds.defaultCards.where((c) => c.visible).map((c) => c.id),
      [
        DashboardCardIds.mealPlanner,
        DashboardCardIds.weight,
        DashboardCardIds.recipes,
        DashboardCardIds.dailyGuidance
      ],
    );
    expect(DashboardCardIds.defaultOrder,
        isNot(contains(DashboardCardIds.foodDiary)));
  });
}
