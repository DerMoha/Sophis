import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/water_entry.dart';
import 'package:sophis/models/weight_entry.dart';
import 'package:sophis/models/workout_entry.dart';
import 'package:sophis/models/supplement.dart';
import 'package:sophis/models/supplement_log.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/meal_plan.dart';
import 'package:sophis/models/custom_portion.dart';
import 'package:sophis/models/user_stats.dart';
part 'database_service.g.dart';

// -----------------------------------------------------------------------------
// TABLES
// -----------------------------------------------------------------------------

class Foods extends Table {
  TextColumn get id => text()(); // Keeping String ID to match existing models
  TextColumn get name => text()();
  RealColumn get calories => real()();
  RealColumn get protein => real()();
  RealColumn get carbs => real()();
  RealColumn get fat => real()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get meal => text()(); // 'breakfast', 'lunch', etc.

  @override
  Set<Column> get primaryKey => {id};
}

class WaterLogs extends Table {
  TextColumn get id => text()();
  RealColumn get amountMl => real()();
  DateTimeColumn get timestamp => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class WeightLogs extends Table {
  TextColumn get id => text()();
  RealColumn get weightKg => real()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get note => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();

  @override
  Set<Column> get primaryKey => {id};
}

class WorkoutLogs extends Table {
  TextColumn get id => text()();
  RealColumn get caloriesBurned => real()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SupplementDefinitions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get reminderTime => text().nullable()(); // "HH:mm" format
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class SupplementLogs extends Table {
  TextColumn get id => text()();
  TextColumn get supplementId => text()();
  DateTimeColumn get timestamp => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class BarcodeProducts extends Table {
  TextColumn get barcode => text()();
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get category => text().nullable()();
  RealColumn get caloriesPer100g => real()();
  RealColumn get proteinPer100g => real()();
  RealColumn get carbsPer100g => real()();
  RealColumn get fatPer100g => real()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get servingsJson => text().nullable()();
  BoolColumn get isUserCorrected =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get cachedAt => dateTime()();
  TextColumn get source => text().withDefault(const Constant('api'))();

  @override
  Set<Column> get primaryKey => {barcode};
}

@DataClassName('RecipeRow')
class Recipes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get ingredientsJson => text()();
  IntColumn get servings => integer().withDefault(const Constant(1))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CustomFoodRow')
class CustomFoods extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  RealColumn get caloriesPer100g => real()();
  RealColumn get proteinPer100g => real()();
  RealColumn get carbsPer100g => real()();
  RealColumn get fatPer100g => real()();
  TextColumn get barcode => text().nullable()();
  TextColumn get brand => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get servingsJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('FavoriteFoodRow')
class FavoriteFoods extends Table {
  TextColumn get id => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PlannedMealRow')
class PlannedMeals extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get meal => text()();
  TextColumn get name => text()();
  RealColumn get calories => real()();
  RealColumn get protein => real()();
  RealColumn get carbs => real()();
  RealColumn get fat => real()();
  TextColumn get recipeId => text().nullable()();
  RealColumn get servings => real().withDefault(const Constant(1))();
  TextColumn get ingredientsJson => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CustomPortionRow')
class CustomPortions extends Table {
  TextColumn get id => text()();
  TextColumn get productKey => text()();
  TextColumn get name => text()();
  RealColumn get grams => real()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RecentFoodRow')
class RecentFoods extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  RealColumn get caloriesPer100g => real()();
  RealColumn get proteinPer100g => real()();
  RealColumn get carbsPer100g => real()();
  RealColumn get fatPer100g => real()();
  TextColumn get barcode => text().nullable()();
  TextColumn get brand => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get servingsJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('UserStatsRow')
class UserStatsTable extends Table {
  TextColumn get id => text().withDefault(const Constant('default'))();
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastLogDate => dateTime().nullable()();
  TextColumn get achievementsJson => text().withDefault(const Constant('[]'))();
  IntColumn get totalDaysLogged => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PlannedMealCheckedRow')
class PlannedMealsChecked extends Table {
  TextColumn get key => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// -----------------------------------------------------------------------------
// DATABASE CLASS
// -----------------------------------------------------------------------------

@DriftDatabase(
  tables: [
    Foods,
    WaterLogs,
    WeightLogs,
    WorkoutLogs,
    SupplementDefinitions,
    SupplementLogs,
    BarcodeProducts,
    Recipes,
    CustomFoods,
    FavoriteFoods,
    PlannedMeals,
    CustomPortions,
    RecentFoods,
    UserStatsTable,
    PlannedMealsChecked,
  ],
)
class DatabaseService extends _$DatabaseService {
  DatabaseService() : super(_openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from == 1) {
            await migrator.createTable(supplementDefinitions);
            await migrator.createTable(supplementLogs);
          }
          if (from <= 2 && to >= 3) {
            await migrator.addColumn(weightLogs, weightLogs.source);
          }
          if (from <= 3 && to >= 4) {
            await migrator.createTable(barcodeProducts);
          }
          if (from <= 4 && to >= 5) {
            await migrator.createTable(recipes);
            await migrator.createTable(customFoods);
            await migrator.createTable(favoriteFoods);
            await migrator.createTable(plannedMeals);
            await migrator.createTable(customPortions);
            await migrator.createTable(recentFoods);
            await migrator.createTable(userStatsTable);
            await migrator.createTable(plannedMealsChecked);
          }
        },
      );

  // ---------------------------------------------------------------------------
  // FOODS
  // ---------------------------------------------------------------------------

  Future<List<FoodEntry>> getAllFoods() async {
    final rows = await select(foods).get();
    return rows
        .map(
          (row) => FoodEntry(
            id: row.id,
            name: row.name,
            calories: row.calories,
            protein: row.protein,
            carbs: row.carbs,
            fat: row.fat,
            timestamp: row.timestamp,
            meal: row.meal,
          ),
        )
        .toList();
  }

  Future<int> insertFood(FoodEntry entry) {
    return into(foods).insert(
      FoodsCompanion(
        id: Value(entry.id),
        name: Value(entry.name),
        calories: Value(entry.calories),
        protein: Value(entry.protein),
        carbs: Value(entry.carbs),
        fat: Value(entry.fat),
        timestamp: Value(entry.timestamp),
        meal: Value(entry.meal),
      ),
    );
  }

  /// Batch insert multiple food entries
  ///
  /// Uses insertOrReplace mode to handle data migration and imports gracefully.
  /// If a record with the same ID exists, it will be replaced with the new data.
  Future<void> insertFoods(List<FoodEntry> entries) async {
    try {
      await batch((batch) {
        batch.insertAll(
          foods,
          entries.map(
            (entry) => FoodsCompanion(
              id: Value(entry.id),
              name: Value(entry.name),
              calories: Value(entry.calories),
              protein: Value(entry.protein),
              carbs: Value(entry.carbs),
              fat: Value(entry.fat),
              timestamp: Value(entry.timestamp),
              meal: Value(entry.meal),
            ),
          ),
          mode: InsertMode.insertOrReplace,
        );
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> updateFood(FoodEntry entry) {
    return update(foods).replace(
      FoodsCompanion(
        id: Value(entry.id),
        name: Value(entry.name),
        calories: Value(entry.calories),
        protein: Value(entry.protein),
        carbs: Value(entry.carbs),
        fat: Value(entry.fat),
        timestamp: Value(entry.timestamp),
        meal: Value(entry.meal),
      ),
    );
  }

  Future<int> deleteFood(String id) {
    return (delete(foods)..where((t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // WATER
  // ---------------------------------------------------------------------------

  Future<List<WaterEntry>> getAllWater() async {
    final rows = await select(waterLogs).get();
    return rows
        .map(
          (row) => WaterEntry(
            id: row.id,
            amountMl: row.amountMl,
            timestamp: row.timestamp,
          ),
        )
        .toList();
  }

  Future<int> insertWater(WaterEntry entry) {
    return into(waterLogs).insert(
      WaterLogsCompanion(
        id: Value(entry.id),
        amountMl: Value(entry.amountMl),
        timestamp: Value(entry.timestamp),
      ),
    );
  }

  /// Batch insert multiple water entries
  ///
  /// Uses insertOrReplace mode for data migration compatibility.
  Future<void> insertWaterList(List<WaterEntry> entries) async {
    await batch((batch) {
      batch.insertAll(
        waterLogs,
        entries.map(
          (entry) => WaterLogsCompanion(
            id: Value(entry.id),
            amountMl: Value(entry.amountMl),
            timestamp: Value(entry.timestamp),
          ),
        ),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<int> deleteWater(String id) {
    return (delete(waterLogs)..where((t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // WEIGHT
  // ---------------------------------------------------------------------------

  Future<List<WeightEntry>> getAllWeights() async {
    final rows = await select(weightLogs).get();
    return rows
        .map(
          (row) => WeightEntry(
            id: row.id,
            weightKg: row.weightKg,
            timestamp: row.timestamp,
            note: row.note,
            source: row.source,
          ),
        )
        .toList();
  }

  Future<int> insertWeight(WeightEntry entry) {
    return into(weightLogs).insert(
      WeightLogsCompanion(
        id: Value(entry.id),
        weightKg: Value(entry.weightKg),
        timestamp: Value(entry.timestamp),
        note: Value(entry.note),
        source: Value(entry.source),
      ),
    );
  }

  Future<void> insertWeightList(List<WeightEntry> entries) async {
    await batch((batch) {
      batch.insertAll(
        weightLogs,
        entries.map(
          (entry) => WeightLogsCompanion(
            id: Value(entry.id),
            weightKg: Value(entry.weightKg),
            timestamp: Value(entry.timestamp),
            note: Value(entry.note),
            source: Value(entry.source),
          ),
        ),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<int> deleteWeight(String id) {
    return (delete(weightLogs)..where((t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // WORKOUTS
  // ---------------------------------------------------------------------------

  Future<List<WorkoutEntry>> getAllWorkouts() async {
    final rows = await select(workoutLogs).get();
    return rows
        .map(
          (row) => WorkoutEntry(
            id: row.id,
            caloriesBurned: row.caloriesBurned,
            timestamp: row.timestamp,
            note: row.note,
          ),
        )
        .toList();
  }

  Future<int> insertWorkout(WorkoutEntry entry) {
    return into(workoutLogs).insert(
      WorkoutLogsCompanion(
        id: Value(entry.id),
        caloriesBurned: Value(entry.caloriesBurned),
        timestamp: Value(entry.timestamp),
        note: Value(entry.note),
      ),
    );
  }

  Future<void> insertWorkoutList(List<WorkoutEntry> entries) async {
    await batch((batch) {
      batch.insertAll(
        workoutLogs,
        entries.map(
          (entry) => WorkoutLogsCompanion(
            id: Value(entry.id),
            caloriesBurned: Value(entry.caloriesBurned),
            timestamp: Value(entry.timestamp),
            note: Value(entry.note),
          ),
        ),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<void> updateWorkout(WorkoutEntry entry) async {
    await update(workoutLogs).replace(
      WorkoutLogsCompanion(
        id: Value(entry.id),
        caloriesBurned: Value(entry.caloriesBurned),
        timestamp: Value(entry.timestamp),
        note: Value(entry.note),
      ),
    );
  }

  Future<int> deleteWorkout(String id) {
    return (delete(workoutLogs)..where((t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // SUPPLEMENTS
  // ---------------------------------------------------------------------------

  Future<List<Supplement>> getAllSupplements() async {
    final rows = await (select(supplementDefinitions)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows
        .map(
          (row) => Supplement(
            id: row.id,
            name: row.name,
            reminderTime: row.reminderTime,
            enabled: row.enabled,
            sortOrder: row.sortOrder,
            createdAt: row.createdAt,
          ),
        )
        .toList();
  }

  Future<int> insertSupplement(Supplement supplement) {
    return into(supplementDefinitions).insert(
      SupplementDefinitionsCompanion(
        id: Value(supplement.id),
        name: Value(supplement.name),
        reminderTime: Value(supplement.reminderTime),
        enabled: Value(supplement.enabled),
        sortOrder: Value(supplement.sortOrder),
        createdAt: Value(supplement.createdAt),
      ),
    );
  }

  Future<bool> updateSupplement(Supplement supplement) {
    return update(supplementDefinitions).replace(
      SupplementDefinitionsCompanion(
        id: Value(supplement.id),
        name: Value(supplement.name),
        reminderTime: Value(supplement.reminderTime),
        enabled: Value(supplement.enabled),
        sortOrder: Value(supplement.sortOrder),
        createdAt: Value(supplement.createdAt),
      ),
    );
  }

  /// Batch update multiple supplements in a single transaction
  ///
  /// More efficient than calling updateSupplement() multiple times, especially
  /// for bulk operations like reordering. All updates succeed or fail together.
  Future<void> batchUpdateSupplements(List<Supplement> supplements) async {
    await batch((batch) {
      for (final supplement in supplements) {
        batch.update(
          supplementDefinitions,
          SupplementDefinitionsCompanion(
            id: Value(supplement.id),
            name: Value(supplement.name),
            reminderTime: Value(supplement.reminderTime),
            enabled: Value(supplement.enabled),
            sortOrder: Value(supplement.sortOrder),
            createdAt: Value(supplement.createdAt),
          ),
          where: ($SupplementDefinitionsTable t) => t.id.equals(supplement.id),
        );
      }
    });
  }

  Future<int> deleteSupplement(String id) {
    return (delete(supplementDefinitions)..where((t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // SUPPLEMENT LOGS
  // ---------------------------------------------------------------------------

  Future<List<SupplementLogEntry>> getAllSupplementLogs() async {
    final rows = await select(supplementLogs).get();
    return rows
        .map(
          (row) => SupplementLogEntry(
            id: row.id,
            supplementId: row.supplementId,
            timestamp: row.timestamp,
          ),
        )
        .toList();
  }

  Future<int> insertSupplementLog(SupplementLogEntry log) {
    return into(supplementLogs).insert(
      SupplementLogsCompanion(
        id: Value(log.id),
        supplementId: Value(log.supplementId),
        timestamp: Value(log.timestamp),
      ),
    );
  }

  Future<int> deleteSupplementLog(String id) {
    return (delete(supplementLogs)..where((t) => t.id.equals(id))).go();
  }

  Future<List<SupplementLogEntry>> getSupplementLogsByDate(
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final rows = await (select(supplementLogs)
          ..where(
            (t) =>
                t.timestamp.isBiggerOrEqualValue(startOfDay) &
                t.timestamp.isSmallerOrEqualValue(endOfDay),
          ))
        .get();

    return rows
        .map(
          (row) => SupplementLogEntry(
            id: row.id,
            supplementId: row.supplementId,
            timestamp: row.timestamp,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // BARCODE PRODUCTS CACHE
  // ---------------------------------------------------------------------------

  Future<BarcodeProduct?> getCachedBarcode(String barcode) async {
    final query = select(barcodeProducts)
      ..where((t) => t.barcode.equals(barcode));
    return query.getSingleOrNull();
  }

  Future<void> upsertBarcodeCache(BarcodeProductsCompanion entry) async {
    await into(barcodeProducts).insertOnConflictUpdate(entry);
  }

  Future<void> deleteExpiredBarcodeCache() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    await (delete(barcodeProducts)
          ..where(
            (t) =>
                t.cachedAt.isSmallerThanValue(cutoff) &
                t.isUserCorrected.equals(false),
          ))
        .go();
  }

  Future<void> deleteBarcodeCache(String barcode) async {
    await (delete(barcodeProducts)..where((t) => t.barcode.equals(barcode)))
        .go();
  }

  // ---------------------------------------------------------------------------
  // UTILS
  // ---------------------------------------------------------------------------

  Future<void> deleteAllData() async {
    await delete(foods).go();
    await delete(waterLogs).go();
    await delete(weightLogs).go();
    await delete(workoutLogs).go();
    await delete(supplementDefinitions).go();
    await delete(supplementLogs).go();
    await delete(barcodeProducts).go();
    await delete(recipes).go();
    await delete(customFoods).go();
    await delete(favoriteFoods).go();
    await delete(plannedMeals).go();
    await delete(customPortions).go();
    await delete(recentFoods).go();
    await delete(userStatsTable).go();
    await delete(plannedMealsChecked).go();
  }

  // ---------------------------------------------------------------------------
  // RECIPES
  // ---------------------------------------------------------------------------

  Future<List<RecipeRow>> getAllRecipes() async {
    return await select(recipes).get();
  }

  Future<int> insertRecipe(RecipeRow recipe) {
    return into(recipes).insert(
      RecipesCompanion(
        id: Value(recipe.id),
        name: Value(recipe.name),
        ingredientsJson: Value(recipe.ingredientsJson),
        servings: Value(recipe.servings),
        notes: Value(recipe.notes),
        createdAt: Value(recipe.createdAt),
      ),
    );
  }

  Future<void> insertRecipes(List<RecipeRow> recipesList) async {
    await batch((batch) {
      batch.insertAll(
        recipes,
        recipesList
            .map(
              (r) => RecipesCompanion(
                id: Value(r.id),
                name: Value(r.name),
                ingredientsJson: Value(r.ingredientsJson),
                servings: Value(r.servings),
                notes: Value(r.notes),
                createdAt: Value(r.createdAt),
              ),
            )
            .toList(),
      );
    });
  }

  Future<int> deleteRecipe(String id) {
    return (delete(recipes)..where((t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // CUSTOM FOODS
  // ---------------------------------------------------------------------------

  Future<List<CustomFoodRow>> getAllCustomFoods() async {
    return await select(customFoods).get();
  }

  Future<int> insertCustomFood(CustomFoodRow food) {
    return into(customFoods).insert(
      CustomFoodsCompanion(
        id: Value(food.id),
        name: Value(food.name),
        category: Value(food.category),
        caloriesPer100g: Value(food.caloriesPer100g),
        proteinPer100g: Value(food.proteinPer100g),
        carbsPer100g: Value(food.carbsPer100g),
        fatPer100g: Value(food.fatPer100g),
        barcode: Value(food.barcode),
        brand: Value(food.brand),
        imageUrl: Value(food.imageUrl),
        servingsJson: Value(food.servingsJson),
      ),
    );
  }

  Future<void> insertCustomFoods(List<CustomFoodRow> foodsList) async {
    await batch((batch) {
      batch.insertAll(
        customFoods,
        foodsList
            .map(
              (f) => CustomFoodsCompanion(
                id: Value(f.id),
                name: Value(f.name),
                category: Value(f.category),
                caloriesPer100g: Value(f.caloriesPer100g),
                proteinPer100g: Value(f.proteinPer100g),
                carbsPer100g: Value(f.carbsPer100g),
                fatPer100g: Value(f.fatPer100g),
                barcode: Value(f.barcode),
                brand: Value(f.brand),
                imageUrl: Value(f.imageUrl),
                servingsJson: Value(f.servingsJson),
              ),
            )
            .toList(),
      );
    });
  }

  Future<int> deleteCustomFood(String id) {
    return (delete(customFoods)..where((t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // FAVORITE FOODS
  // ---------------------------------------------------------------------------

  Future<List<FavoriteFoodRow>> getAllFavoriteFoods() async {
    return await select(favoriteFoods).get();
  }

  Future<int> insertFavoriteFood(FavoriteFoodRow food) {
    return into(favoriteFoods).insert(
      FavoriteFoodsCompanion(
        id: Value(food.id),
      ),
    );
  }

  Future<int> deleteFavoriteFood(String id) {
    return (delete(favoriteFoods)..where((t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // PLANNED MEALS
  // ---------------------------------------------------------------------------

  Future<List<PlannedMealRow>> getAllPlannedMeals() async {
    return await select(plannedMeals).get();
  }

  Future<int> insertPlannedMeal(PlannedMealRow meal) {
    return into(plannedMeals).insert(
      PlannedMealsCompanion(
        id: Value(meal.id),
        date: Value(meal.date),
        meal: Value(meal.meal),
        name: Value(meal.name),
        calories: Value(meal.calories),
        protein: Value(meal.protein),
        carbs: Value(meal.carbs),
        fat: Value(meal.fat),
        recipeId: Value(meal.recipeId),
        servings: Value(meal.servings),
        ingredientsJson: Value(meal.ingredientsJson),
      ),
    );
  }

  Future<void> insertPlannedMeals(List<PlannedMealRow> mealsList) async {
    await batch((batch) {
      batch.insertAll(
        plannedMeals,
        mealsList
            .map(
              (m) => PlannedMealsCompanion(
                id: Value(m.id),
                date: Value(m.date),
                meal: Value(m.meal),
                name: Value(m.name),
                calories: Value(m.calories),
                protein: Value(m.protein),
                carbs: Value(m.carbs),
                fat: Value(m.fat),
                recipeId: Value(m.recipeId),
                servings: Value(m.servings),
                ingredientsJson: Value(m.ingredientsJson),
              ),
            )
            .toList(),
      );
    });
  }

  Future<int> deletePlannedMeal(String id) {
    return (delete(plannedMeals)..where((t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // CUSTOM PORTIONS
  // ---------------------------------------------------------------------------

  Future<List<CustomPortionRow>> getAllCustomPortions() async {
    return await select(customPortions).get();
  }

  Future<int> insertCustomPortion(CustomPortionRow portion) {
    return into(customPortions).insert(
      CustomPortionsCompanion(
        id: Value(portion.id),
        productKey: Value(portion.productKey),
        name: Value(portion.name),
        grams: Value(portion.grams),
        createdAt: Value(portion.createdAt),
      ),
    );
  }

  Future<int> deleteCustomPortion(String id) {
    return (delete(customPortions)..where((t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // RECENT FOODS
  // ---------------------------------------------------------------------------

  Future<List<RecentFoodRow>> getAllRecentFoods() async {
    return await select(recentFoods).get();
  }

  Future<int> insertRecentFood(RecentFoodRow food) {
    return into(recentFoods).insert(
      RecentFoodsCompanion(
        id: Value(food.id),
        name: Value(food.name),
        category: Value(food.category),
        caloriesPer100g: Value(food.caloriesPer100g),
        proteinPer100g: Value(food.proteinPer100g),
        carbsPer100g: Value(food.carbsPer100g),
        fatPer100g: Value(food.fatPer100g),
        barcode: Value(food.barcode),
        brand: Value(food.brand),
        imageUrl: Value(food.imageUrl),
        servingsJson: Value(food.servingsJson),
      ),
    );
  }

  Future<void> replaceRecentFoods(List<RecentFoodRow> foodsList) async {
    await delete(recentFoods).go();
    await batch((batch) {
      batch.insertAll(
        recentFoods,
        foodsList
            .map(
              (f) => RecentFoodsCompanion(
                id: Value(f.id),
                name: Value(f.name),
                category: Value(f.category),
                caloriesPer100g: Value(f.caloriesPer100g),
                proteinPer100g: Value(f.proteinPer100g),
                carbsPer100g: Value(f.carbsPer100g),
                fatPer100g: Value(f.fatPer100g),
                barcode: Value(f.barcode),
                brand: Value(f.brand),
                imageUrl: Value(f.imageUrl),
                servingsJson: Value(f.servingsJson),
              ),
            )
            .toList(),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // USER STATS
  // ---------------------------------------------------------------------------

  Future<UserStatsRow?> getUserStats() async {
    final rows = await (select(userStatsTable)
          ..where((t) => t.id.equals('default')))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsertUserStats(UserStatsRow stats) async {
    await into(userStatsTable).insertOnConflictUpdate(
      UserStatsTableCompanion(
        id: Value(stats.id),
        currentStreak: Value(stats.currentStreak),
        longestStreak: Value(stats.longestStreak),
        lastLogDate: Value(stats.lastLogDate),
        achievementsJson: Value(stats.achievementsJson),
        totalDaysLogged: Value(stats.totalDaysLogged),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PLANNED MEALS CHECKED
  // ---------------------------------------------------------------------------

  Future<List<PlannedMealCheckedRow>> getAllPlannedMealsChecked() async {
    return await select(plannedMealsChecked).get();
  }

  Future<void> replacePlannedMealsChecked(List<String> keys) async {
    await delete(plannedMealsChecked).go();
    await batch((batch) {
      batch.insertAll(
        plannedMealsChecked,
        keys
            .map(
              (k) => PlannedMealsCheckedCompanion(
                key: Value(k),
              ),
            )
            .toList(),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // MIGRATION HELPERS - Convert model classes to row classes and insert
  // ---------------------------------------------------------------------------

  Future<void> migrateRecipe(Recipe recipe) async {
    await into(recipes).insert(
      RecipesCompanion(
        id: Value(recipe.id),
        name: Value(recipe.name),
        ingredientsJson: Value(
          jsonEncode(recipe.ingredients.map((i) => i.toJson()).toList()),
        ),
        servings: Value(recipe.servings),
        notes: Value(recipe.notes),
        createdAt: Value(recipe.createdAt),
      ),
    );
  }

  Future<void> migrateRecipes(List<Recipe> recipesList) async {
    await batch((batch) {
      batch.insertAll(
        recipes,
        recipesList
            .map(
              (r) => RecipesCompanion(
                id: Value(r.id),
                name: Value(r.name),
                ingredientsJson: Value(
                  jsonEncode(r.ingredients.map((i) => i.toJson()).toList()),
                ),
                servings: Value(r.servings),
                notes: Value(r.notes),
                createdAt: Value(r.createdAt),
              ),
            )
            .toList(),
      );
    });
  }

  Future<void> migrateCustomFood(FoodItem food) async {
    await into(customFoods).insert(
      CustomFoodsCompanion(
        id: Value(food.id),
        name: Value(food.name),
        category: Value(food.category),
        caloriesPer100g: Value(food.caloriesPer100g),
        proteinPer100g: Value(food.proteinPer100g),
        carbsPer100g: Value(food.carbsPer100g),
        fatPer100g: Value(food.fatPer100g),
        barcode: Value(food.barcode),
        brand: Value(food.brand),
        imageUrl: Value(food.imageUrl),
        servingsJson: Value(
          jsonEncode(food.servings.map((s) => s.toJson()).toList()),
        ),
      ),
    );
  }

  Future<void> migrateCustomFoods(List<FoodItem> foodsList) async {
    await batch((batch) {
      batch.insertAll(
        customFoods,
        foodsList
            .map(
              (f) => CustomFoodsCompanion(
                id: Value(f.id),
                name: Value(f.name),
                category: Value(f.category),
                caloriesPer100g: Value(f.caloriesPer100g),
                proteinPer100g: Value(f.proteinPer100g),
                carbsPer100g: Value(f.carbsPer100g),
                fatPer100g: Value(f.fatPer100g),
                barcode: Value(f.barcode),
                brand: Value(f.brand),
                imageUrl: Value(f.imageUrl),
                servingsJson: Value(
                  jsonEncode(f.servings.map((s) => s.toJson()).toList()),
                ),
              ),
            )
            .toList(),
      );
    });
  }

  Future<void> migrateFavoriteFoods(List<FoodItem> foods) async {
    await batch((batch) {
      batch.insertAll(
        favoriteFoods,
        foods
            .map(
              (f) => FavoriteFoodsCompanion(
                id: Value(f.id),
              ),
            )
            .toList(),
      );
    });
  }

  Future<void> migratePlannedMeal(PlannedMeal meal) async {
    await into(plannedMeals).insert(
      PlannedMealsCompanion(
        id: Value(meal.id),
        date: Value(meal.date),
        meal: Value(meal.meal),
        name: Value(meal.name),
        calories: Value(meal.calories),
        protein: Value(meal.protein),
        carbs: Value(meal.carbs),
        fat: Value(meal.fat),
        recipeId: Value(meal.recipeId),
        servings: Value(meal.servings),
        ingredientsJson: Value(
          jsonEncode(meal.ingredients.map((i) => i.toJson()).toList()),
        ),
      ),
    );
  }

  Future<void> migratePlannedMeals(List<PlannedMeal> mealsList) async {
    await batch((batch) {
      batch.insertAll(
        plannedMeals,
        mealsList
            .map(
              (m) => PlannedMealsCompanion(
                id: Value(m.id),
                date: Value(m.date),
                meal: Value(m.meal),
                name: Value(m.name),
                calories: Value(m.calories),
                protein: Value(m.protein),
                carbs: Value(m.carbs),
                fat: Value(m.fat),
                recipeId: Value(m.recipeId),
                servings: Value(m.servings),
                ingredientsJson: Value(
                  jsonEncode(m.ingredients.map((i) => i.toJson()).toList()),
                ),
              ),
            )
            .toList(),
      );
    });
  }

  Future<void> migrateCustomPortions(List<CustomPortion> portions) async {
    await batch((batch) {
      batch.insertAll(
        customPortions,
        portions
            .map(
              (p) => CustomPortionsCompanion(
                id: Value(p.id),
                productKey: Value(p.productKey),
                name: Value(p.name),
                grams: Value(p.grams),
                createdAt: Value(p.createdAt),
              ),
            )
            .toList(),
      );
    });
  }

  Future<void> migrateRecentFoods(List<FoodItem> foods) async {
    await replaceRecentFoods(
      foods
          .map(
            (f) => RecentFoodRow(
              id: f.id,
              name: f.name,
              category: f.category,
              caloriesPer100g: f.caloriesPer100g,
              proteinPer100g: f.proteinPer100g,
              carbsPer100g: f.carbsPer100g,
              fatPer100g: f.fatPer100g,
              barcode: f.barcode,
              brand: f.brand,
              imageUrl: f.imageUrl,
              servingsJson:
                  jsonEncode(f.servings.map((s) => s.toJson()).toList()),
            ),
          )
          .toList(),
    );
  }

  Future<void> migrateUserStats(UserStats stats) async {
    await upsertUserStats(
      UserStatsRow(
        id: 'default',
        currentStreak: stats.currentStreak,
        longestStreak: stats.longestStreak,
        lastLogDate: stats.lastLogDate,
        achievementsJson: jsonEncode(stats.achievements),
        totalDaysLogged: stats.totalDaysLogged,
      ),
    );
  }

  Future<void> migratePlannedMealsChecked(Set<String> checked) async {
    await replacePlannedMealsChecked(
      checked.toList(),
    );
  }
}

const _dbFileName = 'sophis_db.sqlite';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = await _resolveDatabaseFile();
    return NativeDatabase.createInBackground(file);
  });
}

Future<File> _resolveDatabaseFile() async {
  final supportDir = await getApplicationSupportDirectory();
  final supportFile = File(p.join(supportDir.path, _dbFileName));

  if (supportFile.existsSync()) {
    return supportFile;
  }

  final legacyDir = await getApplicationDocumentsDirectory();
  final legacyFile = File(p.join(legacyDir.path, _dbFileName));

  if (!legacyFile.existsSync()) {
    supportFile.parent.createSync(recursive: true);
    return supportFile;
  }

  supportFile.parent.createSync(recursive: true);

  try {
    _copyIfNeeded(legacyFile.path, supportFile.path);
    _copyIfNeeded('${legacyFile.path}-wal', '${supportFile.path}-wal');
    _copyIfNeeded('${legacyFile.path}-shm', '${supportFile.path}-shm');
    return supportFile;
  } catch (e) {
    return legacyFile;
  }
}

void _copyIfNeeded(String sourcePath, String destinationPath) {
  final source = File(sourcePath);
  if (!source.existsSync()) {
    return;
  }

  final destination = File(destinationPath);
  if (destination.existsSync()) {
    return;
  }

  source.copySync(destinationPath);
}
