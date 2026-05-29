import 'package:uuid/uuid.dart';

import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/shareable_meal.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/services/service_result.dart';

class FoodIntakeController {
  final NutritionProvider _nutrition;
  final DateTime Function() _now;
  final String Function() _idGenerator;

  FoodIntakeController(
    this._nutrition, {
    DateTime Function()? now,
    String Function()? idGenerator,
  })  : _now = now ?? DateTime.now,
        _idGenerator = idGenerator ?? _generateId;

  Future<ServiceResult<FoodEntry>> logFoodItem({
    required FoodItem item,
    required double grams,
    required String meal,
  }) async {
    final mealError = _validateText(meal, 'Meal is required');
    if (mealError != null) return _failure(mealError);

    final nameError = _validateText(item.name, 'Food name is required');
    if (nameError != null) return _failure(nameError);

    if (grams <= 0) {
      return _failure('Portion must be greater than zero');
    }

    final nutrients = item.calculateFor(grams);
    final nutritionError = _validateNutrition(
      calories: nutrients.calories,
      protein: nutrients.protein,
      carbs: nutrients.carbs,
      fat: nutrients.fat,
      fiber: nutrients.fiber,
    );
    if (nutritionError != null) return _failure(nutritionError);

    final displayName = item.brand != null && item.brand!.isNotEmpty
        ? '${item.brand} ${item.name}'
        : item.name;
    final entry = _createEntry(
      name: '$displayName (${grams.toStringAsFixed(0)}g)',
      calories: nutrients.calories,
      protein: nutrients.protein,
      carbs: nutrients.carbs,
      fat: nutrients.fat,
      fiber: nutrients.fiber,
      meal: meal,
    );

    try {
      await _nutrition.addFoodEntry(entry);
      await _nutrition.addRecentFood(item, meal: meal);
      return Success(entry);
    } catch (e) {
      return _unknownFailure(e);
    }
  }

  Future<ServiceResult<FoodEntry>> logNutritionEntry({
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    double fiber = 0,
    required String meal,
  }) async {
    final validation = _validateEntryInput(
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      meal: meal,
    );
    if (validation != null) return _failure(validation);

    final entry = _createEntry(
      name: name.trim(),
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      meal: meal,
    );

    try {
      await _nutrition.addFoodEntry(entry);
      return Success(entry);
    } catch (e) {
      return _unknownFailure(e);
    }
  }

  Future<ServiceResult<FoodEntry>> logManualEntry({
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    double fiber = 0,
    required String meal,
    bool saveAsCustomFood = false,
  }) async {
    final validation = _validateEntryInput(
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      meal: meal,
    );
    if (validation != null) return _failure(validation);

    final trimmedName = name.trim();
    final entry = _createEntry(
      name: trimmedName,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      meal: meal,
    );

    try {
      await _nutrition.addFoodEntry(entry);
      if (saveAsCustomFood) {
        await _nutrition.addCustomFood(
          _createCustomFood(
            name: trimmedName,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
          ),
        );
      }
      return Success(entry);
    } catch (e) {
      return _unknownFailure(e);
    }
  }

  Future<ServiceResult<List<FoodEntry>>> importSharedMeal({
    required ShareableMeal meal,
    required String targetMeal,
  }) async {
    final mealError = _validateText(targetMeal, 'Meal is required');
    if (mealError != null) {
      return Failure(ServiceErrorType.parseError, mealError);
    }

    final entries = <FoodEntry>[];
    for (final item in meal.items) {
      final validation = _validateEntryInput(
        name: item.name,
        calories: item.calories,
        protein: item.protein,
        carbs: item.carbs,
        fat: item.fat,
        fiber: item.fiber,
        meal: targetMeal,
      );
      if (validation != null) {
        return Failure(ServiceErrorType.parseError, validation);
      }

      entries.add(
        _createEntry(
          name: item.name.trim(),
          calories: item.calories,
          protein: item.protein,
          carbs: item.carbs,
          fat: item.fat,
          fiber: item.fiber,
          meal: targetMeal,
        ),
      );
    }

    try {
      for (final entry in entries) {
        await _nutrition.addFoodEntry(entry);
      }
      return Success(entries);
    } catch (e) {
      return Failure(ServiceErrorType.unknown, e.toString());
    }
  }

  Future<ServiceResult<FoodEntry>> saveEntryAsCustomFood(
    FoodEntry entry,
  ) async {
    final validation = _validateEntryInput(
      name: entry.name,
      calories: entry.calories,
      protein: entry.protein,
      carbs: entry.carbs,
      fat: entry.fat,
      fiber: entry.fiber,
      meal: entry.meal,
    );
    if (validation != null) return _failure(validation);

    try {
      await _nutrition.addCustomFood(
        _createCustomFood(
          name: entry.name.trim(),
          calories: entry.calories,
          protein: entry.protein,
          carbs: entry.carbs,
          fat: entry.fat,
          fiber: entry.fiber,
        ),
      );
      return Success(entry);
    } catch (e) {
      return _unknownFailure(e);
    }
  }

  FoodEntry _createEntry({
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required double fiber,
    required String meal,
  }) {
    return FoodEntry(
      id: _idGenerator(),
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      timestamp: _now(),
      meal: meal,
    );
  }

  FoodItem _createCustomFood({
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required double fiber,
  }) {
    return FoodItem(
      id: 'custom_${_idGenerator()}',
      name: name,
      category: 'custom',
      caloriesPer100g: calories,
      proteinPer100g: protein,
      carbsPer100g: carbs,
      fatPer100g: fat,
      fiberPer100g: fiber,
    );
  }

  String? _validateEntryInput({
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required double fiber,
    required String meal,
  }) {
    return _validateText(name, 'Food name is required') ??
        _validateText(meal, 'Meal is required') ??
        _validateNutrition(
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          fiber: fiber,
        );
  }

  String? _validateText(String value, String message) {
    if (value.trim().isEmpty) return message;
    return null;
  }

  String? _validateNutrition({
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required double fiber,
  }) {
    if (calories < 0 || protein < 0 || carbs < 0 || fat < 0 || fiber < 0) {
      return 'Nutrition values cannot be negative';
    }
    return null;
  }

  Failure<FoodEntry> _failure(String message) {
    return Failure(ServiceErrorType.parseError, message);
  }

  Failure<FoodEntry> _unknownFailure(Object error) {
    return Failure(ServiceErrorType.unknown, error.toString());
  }

  static String _generateId() => const Uuid().v4();
}
