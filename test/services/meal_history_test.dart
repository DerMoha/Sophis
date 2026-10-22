import 'package:flutter_test/flutter_test.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/nutrition_unit.dart';

import '../helpers/test_services.dart';

void main() {
  test('recovered old scanned breakfast foods and persisted extended recent history', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final provider = await createLoadedNutritionProvider(database: db);
    await provider.addFoodEntry(FoodEntry(id: 'old', name: 'Old oats (80g)',
      calories: 160, protein: 8, carbs: 20, fat: 4, meal: 'breakfast',
      portionAmount: 80, portionUnit: NutritionUnit.gram, sourceFoodId: 'oats',
      timestamp: DateTime(2026, 1, 1),),);
    for (var i = 0; i < 26; i++) {
      await provider.addRecentFood(FoodItem(id: 'recent-$i', name: 'Food $i',
        category: 'food', caloriesPer100g: 100, proteinPer100g: 2,
        carbsPer100g: 20, fatPer100g: 2,), meal: 'breakfast',);
    }
    await provider.reloadAll();
    final foods = provider.getRecentFoodsForMeal('breakfast');
    expect(foods, hasLength(27));
    final oats = foods.singleWhere((food) => food.id == 'oats');
    expect(oats.name, 'Old oats');
    expect(oats.caloriesPer100g, 200);
    expect(oats.lastUsedPortion!.amount, 80);
  });
}
