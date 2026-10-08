import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/shareable_meal.dart';
import 'package:sophis/models/social/social_snapshot.dart';
import 'package:sophis/ui/components/organic_components.dart';
import 'package:sophis/ui/screens/social/partner_meals.dart';

void main() {
  Map<String, dynamic> meal(String name, String? category) => {
        'mealCategory': category,
        'snapshot': SocialSnapshot(
          title: name,
          servings: 1,
          items: [
            SharedFoodItem(
                name: name, calories: 100, protein: 2, carbs: 20, fat: 1,),
          ],
        ).toJson(nutritionVisible: true),
      };

  testWidgets(
      'grouped food by the author category and kept legacy items visible',
      (tester) async {
    Map<String, dynamic>? imported;
    final dinner = meal('Rice', 'dinner');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PartnerMeals(
              meals: [
                meal('Oats', 'breakfast'),
                dinner,
                meal('Apple', 'snack'),
                meal('Older food', null),
              ],
              onImport: (record) => imported = record,
            ),
          ),
        ),
      ),
    );
    final cards = tester.widgetList<MealCard>(find.byType(MealCard)).toList();
    expect(cards.map((card) => card.title),
        ['Breakfast', 'Lunch', 'Dinner', 'Snacks', 'Other meals'],);
    expect(cards[2].calories, 100);
    expect((cards[2].entries.single as FoodEntryTile).name, 'Rice');
    expect(cards[1].entries, isEmpty);
    await tester.ensureVisible(find.text('Rice'));
    await tester.tap(find.text('Rice'));
    expect(imported, same(dinner));
    expect(tester.takeException(), isNull);
  });
}
