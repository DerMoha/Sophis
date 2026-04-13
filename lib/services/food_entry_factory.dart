import 'package:uuid/uuid.dart';

import '../models/food_entry.dart';
import '../models/food_item.dart';

class FoodEntryFactory {
  static const Uuid _uuid = Uuid();

  static FoodEntry create({
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required String meal,
    DateTime? timestamp,
    String? id,
  }) {
    return FoodEntry(
      id: id ?? _uuid.v4(),
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      timestamp: timestamp ?? DateTime.now(),
      meal: meal,
    );
  }

  static FoodEntry fromFoodItem({
    required FoodItem item,
    required double grams,
    required String meal,
    DateTime? timestamp,
    String? id,
  }) {
    final nutrients = item.calculateFor(grams);
    final displayName = item.brand != null && item.brand!.isNotEmpty
        ? '${item.brand} ${item.name}'
        : item.name;

    return create(
      id: id,
      name: '$displayName (${grams.toStringAsFixed(0)}g)',
      calories: nutrients.calories,
      protein: nutrients.protein,
      carbs: nutrients.carbs,
      fat: nutrients.fat,
      meal: meal,
      timestamp: timestamp,
    );
  }

  static FoodItem createCustomFood({
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    String? id,
  }) {
    return FoodItem(
      id: id ?? 'custom_${_uuid.v4()}',
      name: name,
      category: 'custom',
      caloriesPer100g: calories,
      proteinPer100g: protein,
      carbsPer100g: carbs,
      fatPer100g: fat,
    );
  }

  static FoodItem customFoodFromEntry(FoodEntry entry, {String? id}) {
    return createCustomFood(
      id: id,
      name: entry.name,
      calories: entry.calories,
      protein: entry.protein,
      carbs: entry.carbs,
      fat: entry.fat,
    );
  }
}
