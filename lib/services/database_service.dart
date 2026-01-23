import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/food_entry.dart';
import '../models/water_entry.dart';
import '../models/weight_entry.dart';
import '../models/workout_entry.dart';
import '../models/supplement.dart';
import '../models/supplement_log.dart';

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

// -----------------------------------------------------------------------------
// DATABASE CLASS
// -----------------------------------------------------------------------------

@DriftDatabase(tables: [Foods, WaterLogs, WeightLogs, WorkoutLogs, SupplementDefinitions, SupplementLogs])
class DatabaseService extends _$DatabaseService {
  DatabaseService() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from == 1 && to == 2) {
        await migrator.createTable(supplementDefinitions);
        await migrator.createTable(supplementLogs);
      }
    },
  );

  // ---------------------------------------------------------------------------
  // FOODS
  // ---------------------------------------------------------------------------

  Future<List<FoodEntry>> getAllFoods() async {
    final rows = await select(foods).get();
    return rows
        .map((row) => FoodEntry(
              id: row.id,
              name: row.name,
              calories: row.calories,
              protein: row.protein,
              carbs: row.carbs,
              fat: row.fat,
              timestamp: row.timestamp,
              meal: row.meal,
            ))
        .toList();
  }

  Future<int> insertFood(FoodEntry entry) {
    return into(foods).insert(FoodsCompanion(
      id: Value(entry.id),
      name: Value(entry.name),
      calories: Value(entry.calories),
      protein: Value(entry.protein),
      carbs: Value(entry.carbs),
      fat: Value(entry.fat),
      timestamp: Value(entry.timestamp),
      meal: Value(entry.meal),
    ));
  }

  Future<void> insertFoods(List<FoodEntry> entries) async {
    await batch((batch) {
      batch.insertAll(
        foods,
        entries.map((entry) => FoodsCompanion(
              id: Value(entry.id),
              name: Value(entry.name),
              calories: Value(entry.calories),
              protein: Value(entry.protein),
              carbs: Value(entry.carbs),
              fat: Value(entry.fat),
              timestamp: Value(entry.timestamp),
              meal: Value(entry.meal),
            )),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<bool> updateFood(FoodEntry entry) {
    return update(foods).replace(FoodsCompanion(
      id: Value(entry.id),
      name: Value(entry.name),
      calories: Value(entry.calories),
      protein: Value(entry.protein),
      carbs: Value(entry.carbs),
      fat: Value(entry.fat),
      timestamp: Value(entry.timestamp),
      meal: Value(entry.meal),
    ));
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
        .map((row) => WaterEntry(
              id: row.id,
              amountMl: row.amountMl,
              timestamp: row.timestamp,
            ))
        .toList();
  }

  Future<int> insertWater(WaterEntry entry) {
    return into(waterLogs).insert(WaterLogsCompanion(
      id: Value(entry.id),
      amountMl: Value(entry.amountMl),
      timestamp: Value(entry.timestamp),
    ));
  }

  Future<void> insertWaterList(List<WaterEntry> entries) async {
    await batch((batch) {
      batch.insertAll(
        waterLogs,
        entries.map((entry) => WaterLogsCompanion(
              id: Value(entry.id),
              amountMl: Value(entry.amountMl),
              timestamp: Value(entry.timestamp),
            )),
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
        .map((row) => WeightEntry(
              id: row.id,
              weightKg: row.weightKg,
              timestamp: row.timestamp,
              note: row.note,
            ))
        .toList();
  }

  Future<int> insertWeight(WeightEntry entry) {
    return into(weightLogs).insert(WeightLogsCompanion(
      id: Value(entry.id),
      weightKg: Value(entry.weightKg),
      timestamp: Value(entry.timestamp),
      note: Value(entry.note),
    ));
  }

  Future<void> insertWeightList(List<WeightEntry> entries) async {
    await batch((batch) {
      batch.insertAll(
        weightLogs,
        entries.map((entry) => WeightLogsCompanion(
              id: Value(entry.id),
              weightKg: Value(entry.weightKg),
              timestamp: Value(entry.timestamp),
              note: Value(entry.note),
            )),
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
        .map((row) => WorkoutEntry(
              id: row.id,
              caloriesBurned: row.caloriesBurned,
              timestamp: row.timestamp,
              note: row.note,
            ))
        .toList();
  }

  Future<int> insertWorkout(WorkoutEntry entry) {
    return into(workoutLogs).insert(WorkoutLogsCompanion(
      id: Value(entry.id),
      caloriesBurned: Value(entry.caloriesBurned),
      timestamp: Value(entry.timestamp),
      note: Value(entry.note),
    ));
  }

  Future<void> insertWorkoutList(List<WorkoutEntry> entries) async {
    await batch((batch) {
      batch.insertAll(
        workoutLogs,
        entries.map((entry) => WorkoutLogsCompanion(
              id: Value(entry.id),
              caloriesBurned: Value(entry.caloriesBurned),
              timestamp: Value(entry.timestamp),
              note: Value(entry.note),
            )),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<void> updateWorkout(WorkoutEntry entry) async {
    await update(workoutLogs).replace(WorkoutLogsCompanion(
      id: Value(entry.id),
      caloriesBurned: Value(entry.caloriesBurned),
      timestamp: Value(entry.timestamp),
      note: Value(entry.note),
    ));
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
        .map((row) => Supplement(
              id: row.id,
              name: row.name,
              reminderTime: row.reminderTime,
              enabled: row.enabled,
              sortOrder: row.sortOrder,
              createdAt: row.createdAt,
            ))
        .toList();
  }

  Future<int> insertSupplement(Supplement supplement) {
    return into(supplementDefinitions).insert(SupplementDefinitionsCompanion(
      id: Value(supplement.id),
      name: Value(supplement.name),
      reminderTime: Value(supplement.reminderTime),
      enabled: Value(supplement.enabled),
      sortOrder: Value(supplement.sortOrder),
      createdAt: Value(supplement.createdAt),
    ));
  }

  Future<bool> updateSupplement(Supplement supplement) {
    return update(supplementDefinitions).replace(SupplementDefinitionsCompanion(
      id: Value(supplement.id),
      name: Value(supplement.name),
      reminderTime: Value(supplement.reminderTime),
      enabled: Value(supplement.enabled),
      sortOrder: Value(supplement.sortOrder),
      createdAt: Value(supplement.createdAt),
    ));
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
        .map((row) => SupplementLogEntry(
              id: row.id,
              supplementId: row.supplementId,
              timestamp: row.timestamp,
            ))
        .toList();
  }

  Future<int> insertSupplementLog(SupplementLogEntry log) {
    return into(supplementLogs).insert(SupplementLogsCompanion(
      id: Value(log.id),
      supplementId: Value(log.supplementId),
      timestamp: Value(log.timestamp),
    ));
  }

  Future<int> deleteSupplementLog(String id) {
    return (delete(supplementLogs)..where((t) => t.id.equals(id))).go();
  }

  Future<List<SupplementLogEntry>> getSupplementLogsByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final rows = await (select(supplementLogs)
          ..where((t) => t.timestamp.isBiggerOrEqualValue(startOfDay) &
                         t.timestamp.isSmallerOrEqualValue(endOfDay)))
        .get();

    return rows
        .map((row) => SupplementLogEntry(
              id: row.id,
              supplementId: row.supplementId,
              timestamp: row.timestamp,
            ))
        .toList();
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
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'sophis_db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
