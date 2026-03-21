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
  TextColumn get source =>
      text().withDefault(const Constant('api'))();

  @override
  Set<Column> get primaryKey => {barcode};
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
  ],
)
class DatabaseService extends _$DatabaseService {
  DatabaseService() : super(_openConnection());

  @override
  int get schemaVersion => 4;

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
    await (delete(barcodeProducts)
          ..where((t) => t.barcode.equals(barcode)))
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
