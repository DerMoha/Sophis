import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/models/shareable_meal.dart';

/// Explicit social whitelist. No source IDs, diary dates, health data or paths.
final class SocialSnapshot {
  static const int schemaVersion = 1;
  final String title;
  final double servings;
  final bool nutritionAvailable;
  final List<SharedFoodItem> items;

  SocialSnapshot({
    required this.title,
    required this.servings,
    this.nutritionAvailable = true,
    required List<SharedFoodItem> items,
  }) : items = List.unmodifiable(items) {
    if (title.trim().isEmpty ||
        title.length > 160 ||
        !servings.isFinite ||
        servings <= 0 ||
        servings > 1000 ||
        items.isEmpty ||
        items.length > 50) {
      throw const FormatException('Invalid social snapshot');
    }
    for (final item in items) {
      if (item.name.trim().isEmpty || item.name.length > 160) {
        throw const FormatException('Invalid social item');
      }
      final nutrients = [
        item.calories,
        item.protein,
        item.carbs,
        item.fat,
        item.fiber,
      ];
      for (var index = 0; index < nutrients.length; index++) {
        final value = nutrients[index];
        if (!value.isFinite ||
            value < 0 ||
            value > (index == 0 ? 100000 : 10000)) {
          throw const FormatException('Invalid social nutrition');
        }
      }
      final amount = item.portionGrams;
      if (amount != null &&
          (!amount.isFinite ||
              amount <= 0 ||
              amount > 100000 ||
              item.portionUnit == null)) {
        throw const FormatException('Invalid social portion');
      }
      final quantity = item.portionQuantity;
      if (quantity != null &&
          (!quantity.isFinite || quantity <= 0 || quantity > 10000)) {
        throw const FormatException('Invalid social quantity');
      }
    }
  }

  factory SocialSnapshot.fromEntries(
    List<FoodEntry> entries, {
    required String title,
  }) =>
      SocialSnapshot(
        title: title,
        servings: 1,
        items: entries.map(SharedFoodItem.fromFoodEntry).toList(),
      );

  factory SocialSnapshot.fromRecipe(Recipe recipe) => SocialSnapshot(
        title: recipe.name,
        servings: recipe.servings.toDouble(),
        items: recipe.ingredients
            .map(
              (item) => SharedFoodItem(
                name: item.name,
                calories: item.calories,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat,
                fiber: item.fiber,
                portionGrams: item.amountGrams,
                portionUnit: NutritionUnit.gram,
              ),
            )
            .toList(),
      );

  Map<String, dynamic> toJson({required bool nutritionVisible}) => {
        'schemaVersion': schemaVersion,
        'title': title,
        'servings': servings,
        'items': items
            .map(
              (item) => <String, dynamic>{
                'name': item.name,
                if (nutritionVisible) ...{
                  'calories': item.calories,
                  'protein': item.protein,
                  'carbs': item.carbs,
                  'fat': item.fat,
                  'fiber': item.fiber,
                },
                if (item.portionGrams != null) ...{
                  'portionAmount': item.portionGrams,
                  'portionUnit': item.portionUnit?.symbol,
                },
                if (item.portionLabel != null)
                  'portionLabel': item.portionLabel,
                if (item.portionQuantity != null)
                  'portionQuantity': item.portionQuantity,
              },
            )
            .toList(),
      };

  /// Nutrient-free posts can be viewed/saved, but cannot be logged as zero calories.
  /// Callers must obtain nutrition before diary import when it was hidden.
  factory SocialSnapshot.fromJson(
    Map<String, dynamic> json, {
    required bool nutritionVisible,
  }) {
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported social snapshot version');
    }
    return SocialSnapshot(
      title: json['title'] as String,
      nutritionAvailable: nutritionVisible,
      servings: (json['servings'] as num).toDouble(),
      items: (json['items'] as List).map((value) {
        final item = value as Map<String, dynamic>;
        double nutrient(String key) =>
            nutritionVisible ? (item[key] as num).toDouble() : 0;
        final unit = item['portionUnit'];
        if (unit != null && unit != 'g' && unit != 'ml') {
          throw const FormatException('Unsupported social portion unit');
        }
        return SharedFoodItem(
          name: item['name'] as String,
          calories: nutrient('calories'),
          protein: nutrient('protein'),
          carbs: nutrient('carbs'),
          fat: nutrient('fat'),
          fiber: nutrient('fiber'),
          portionGrams: (item['portionAmount'] as num?)?.toDouble(),
          portionUnit:
              unit == null ? null : NutritionUnitX.fromStorage(unit as String),
          portionLabel: item['portionLabel'] as String?,
          portionQuantity: (item['portionQuantity'] as num?)?.toDouble(),
        );
      }).toList(),
    );
  }

  /// Deterministic new IDs let a transactional local import safely retry.
  /// A new operation ID represents an intentional repeat meal.
  List<FoodEntry> entriesForImport({
    required String operationId,
    required double selectedServings,
    required DateTime timestamp,
    required String meal,
    required bool nutritionVisible,
  }) {
    if (!nutritionVisible || !nutritionAvailable) {
      throw StateError('Nutrition is required before diary import');
    }
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(operationId) ||
        !selectedServings.isFinite ||
        selectedServings <= 0 ||
        selectedServings > 1000 ||
        !['breakfast', 'lunch', 'dinner', 'snack'].contains(meal)) {
      throw const FormatException('Invalid import selection');
    }
    final factor = selectedServings / servings;
    return [
      for (var index = 0; index < items.length; index++)
        FoodEntry(
          id: 'social_import_${operationId}_$index',
          name: items[index].name,
          calories: items[index].calories * factor,
          protein: items[index].protein * factor,
          carbs: items[index].carbs * factor,
          fat: items[index].fat * factor,
          fiber: items[index].fiber * factor,
          timestamp: timestamp,
          meal: meal,
          portionAmount: items[index].portionGrams == null
              ? null
              : items[index].portionGrams! * factor,
          portionUnit: items[index].portionUnit,
          portionLabel: items[index].portionLabel,
          portionQuantity: items[index].portionQuantity == null
              ? null
              : items[index].portionQuantity! * factor,
        ),
    ];
  }
}
