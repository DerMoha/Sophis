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
import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/models/meal_plan.dart';
import 'package:sophis/models/custom_portion.dart';
import 'package:sophis/models/user_stats.dart';
import 'package:sophis/models/progress_photo.dart';
part 'database_service.g.dart';

// -----------------------------------------------------------------------------
// TABLES
// -----------------------------------------------------------------------------

@TableIndex(
  name: 'foods_timestamp_idx',
  columns: {
    IndexedColumn(#timestamp, orderBy: OrderingMode.desc),
    #id,
  },
)
class Foods extends Table {
  TextColumn get id => text()(); // Keeping String ID to match existing models
  TextColumn get name => text()();
  RealColumn get calories => real()();
  RealColumn get protein => real()();
  RealColumn get carbs => real()();
  RealColumn get fat => real()();
  RealColumn get fiber => real().withDefault(const Constant(0))();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get meal => text()(); // 'breakfast', 'lunch', etc.
  TextColumn get sourceFoodId => text().nullable()();
  RealColumn get portionAmount => real().nullable()();
  TextColumn get portionUnit => text().nullable()();
  TextColumn get portionLabel => text().nullable()();
  RealColumn get portionQuantity => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local-only immutable logging facts used to filter partner sharing. No diary
/// content or account identity is stored here, and this is not a cloud outbox.
@DataClassName('FoodSharingOriginRow')
@TableIndex(name: 'food_sharing_origins_sequence_idx', columns: {#sequence})
class FoodSharingOrigins extends Table {
  TextColumn get foodId => text()();
  IntColumn get originallyLoggedAt => integer().nullable()();
  IntColumn get changedAt => integer()();
  IntColumn get revision => integer()();
  IntColumn get sequence => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {foodId};
}

@TableIndex(
  name: 'water_logs_timestamp_idx',
  columns: {
    IndexedColumn(#timestamp, orderBy: OrderingMode.desc),
    #id,
  },
)
class WaterLogs extends Table {
  TextColumn get id => text()();
  RealColumn get amountMl => real()();
  DateTimeColumn get timestamp => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(
  name: 'weight_logs_timestamp_idx',
  columns: {
    IndexedColumn(#timestamp, orderBy: OrderingMode.desc),
    #id,
  },
)
class WeightLogs extends Table {
  TextColumn get id => text()();
  RealColumn get weightKg => real()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get note => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(
  name: 'workout_logs_timestamp_idx',
  columns: {
    IndexedColumn(#timestamp, orderBy: OrderingMode.desc),
    #id,
  },
)
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

@TableIndex(
  name: 'supplement_logs_timestamp_idx',
  columns: {
    IndexedColumn(#timestamp, orderBy: OrderingMode.desc),
    #id,
  },
)
class SupplementLogs extends Table {
  TextColumn get id => text()();
  TextColumn get supplementId =>
      text().references(SupplementDefinitions, #id)();
  DateTimeColumn get timestamp => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(
  name: 'barcode_products_expiry_idx',
  columns: {
    #cacheStatus,
    IndexedColumn(#cachedAt, orderBy: OrderingMode.asc),
  },
)
class BarcodeProducts extends Table {
  TextColumn get barcode => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get brand => text().nullable()();
  TextColumn get category => text().nullable()();
  RealColumn get caloriesPer100g => real().withDefault(const Constant(0))();
  RealColumn get proteinPer100g => real().withDefault(const Constant(0))();
  RealColumn get carbsPer100g => real().withDefault(const Constant(0))();
  RealColumn get fatPer100g => real().withDefault(const Constant(0))();
  RealColumn get fiberPer100g => real().withDefault(const Constant(0))();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get servingsJson => text().nullable()();
  TextColumn get cacheStatus => text().withDefault(const Constant('found'))();
  BoolColumn get isUserCorrected =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get cachedAt => dateTime()();
  TextColumn get source => text().withDefault(const Constant('api'))();
  TextColumn get nutritionUnit => text().withDefault(const Constant('gram'))();

  @override
  Set<Column> get primaryKey => {barcode};
}

@DataClassName('RecipeRow')
@TableIndex(
  name: 'recipes_created_at_idx',
  columns: {
    IndexedColumn(#createdAt, orderBy: OrderingMode.desc),
    #id,
  },
)
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
  RealColumn get fiberPer100g => real().withDefault(const Constant(0))();
  TextColumn get barcode => text().nullable()();
  TextColumn get brand => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get servingsJson => text().nullable()();
  TextColumn get nutritionUnit => text().withDefault(const Constant('gram'))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('FavoriteFoodRow')
class FavoriteFoods extends Table {
  TextColumn get id => text()();

  /// Snapshot of the food at the time it was favorited.
  ///
  /// This is nullable for backwards compatibility with the original
  /// id-only favorites table. Newer callers can fill it during the canonical
  /// library cutover without rewriting existing rows.
  TextColumn get foodJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PlannedMealRow')
@TableIndex(
  name: 'planned_meals_schedule_idx',
  columns: {
    IndexedColumn(#date, orderBy: OrderingMode.asc),
    #meal,
    #id,
  },
)
class PlannedMeals extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get meal => text()();
  TextColumn get name => text()();
  RealColumn get calories => real()();
  RealColumn get protein => real()();
  RealColumn get carbs => real()();
  RealColumn get fat => real()();
  RealColumn get fiber => real().withDefault(const Constant(0))();
  TextColumn get recipeId => text().nullable()();
  RealColumn get servings => real().withDefault(const Constant(1))();
  TextColumn get ingredientsJson => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CustomPortionRow')
@TableIndex(
  name: 'custom_portions_product_idx',
  columns: {
    #productKey,
    IndexedColumn(#createdAt, orderBy: OrderingMode.asc),
    #id,
  },
)
class CustomPortions extends Table {
  TextColumn get id => text()();
  TextColumn get productKey => text()();
  TextColumn get name => text()();
  RealColumn get grams => real()();
  TextColumn get unit => text().withDefault(const Constant('gram'))();
  TextColumn get displayLabel => text().nullable()();
  RealColumn get displayQuantity => real().nullable()();
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
  RealColumn get fiberPer100g => real().withDefault(const Constant(0))();
  TextColumn get barcode => text().nullable()();
  TextColumn get brand => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get servingsJson => text().nullable()();
  TextColumn get nutritionUnit => text().withDefault(const Constant('gram'))();

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

/// Canonical JSON documents for nutrition collections that are loaded and
/// replaced as a whole. Keeping these in SQLite gives migration and backup a
/// single transactional authority without leaking Drift row types to callers.
class NutritionDocuments extends Table {
  TextColumn get key => text()();
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('ProgressPhotoRow')
@TableIndex(
  name: 'progress_photos_category_timestamp_idx',
  columns: {
    #category,
    IndexedColumn(#timestamp, orderBy: OrderingMode.desc),
    #id,
  },
)
class ProgressPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get imagePath => text()();
  DateTimeColumn get timestamp => dateTime()();
  RealColumn get weightKg => real().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get category => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A stable local scope that can later be bound to a cloud account.
@DataClassName('DataSpaceRow')
class DataSpaces extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Records durable, retryable local migration progress.
@DataClassName('MigrationStateRow')
class MigrationState extends Table {
  TextColumn get key => text()();
  IntColumn get version => integer()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get checksum => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Generic per-entity sync metadata. Domain tables remain unchanged until the
/// canonical entity cutover; this table provides the future sync seam now.
@DataClassName('SyncMetadataRow')
@TableIndex(
  name: 'sync_metadata_space_entity_idx',
  columns: {
    #dataSpaceId,
    #entityType,
    #entityId,
  },
)
@TableIndex(
  name: 'sync_metadata_pending_idx',
  columns: {
    #dataSpaceId,
    IndexedColumn(#updatedAt, orderBy: OrderingMode.desc),
  },
)
class SyncMetadata extends Table {
  TextColumn get dataSpaceId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  IntColumn get localRevision => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get remoteVersion => text().nullable()();

  @override
  Set<Column> get primaryKey => {dataSpaceId, entityType, entityId};
}

/// Durable mutation queue for a future cloud synchronizer.
@DataClassName('SyncOutboxRow')
@TableIndex(
  name: 'sync_outbox_pending_idx',
  columns: {
    #dataSpaceId,
    #processedAt,
    IndexedColumn(#createdAt, orderBy: OrderingMode.asc),
  },
)
@TableIndex(
  name: 'sync_outbox_entity_idx',
  columns: {
    #dataSpaceId,
    #entityType,
    #entityId,
  },
)
class SyncOutbox extends Table {
  TextColumn get id => text()();
  TextColumn get dataSpaceId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payloadJson => text().nullable()();
  IntColumn get baseRevision => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  DateTimeColumn get processedAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Pull cursor for one local data space and remote scope.
@DataClassName('SyncCheckpointRow')
class SyncCheckpoints extends Table {
  TextColumn get dataSpaceId => text()();
  TextColumn get remoteScope => text()();
  TextColumn get cursor => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {dataSpaceId, remoteScope};
}

/// Idempotency ledger for remote changes already applied locally.
@DataClassName('SyncAppliedChangeRow')
@TableIndex(
  name: 'sync_applied_changes_entity_idx',
  columns: {
    #dataSpaceId,
    #entityType,
    #entityId,
  },
)
class SyncAppliedChanges extends Table {
  TextColumn get dataSpaceId => text()();
  TextColumn get remoteChangeId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  DateTimeColumn get appliedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {dataSpaceId, remoteChangeId};
}

/// Crash-safe staging intents for progress photo file operations.
@DataClassName('PhotoFileIntentRow')
@TableIndex(
  name: 'photo_file_intents_pending_idx',
  columns: {
    #dataSpaceId,
    #processedAt,
    IndexedColumn(#createdAt, orderBy: OrderingMode.asc),
  },
)
@TableIndex(
  name: 'photo_file_intents_photo_idx',
  columns: {
    #dataSpaceId,
    #photoId,
  },
)
class PhotoFileIntents extends Table {
  TextColumn get id => text()();
  TextColumn get dataSpaceId => text()();
  TextColumn get photoId => text()();
  TextColumn get operation => text()();
  TextColumn get path => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get processedAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// -----------------------------------------------------------------------------
// DATABASE CLASS
// -----------------------------------------------------------------------------

@DriftDatabase(
  tables: [
    Foods,
    FoodSharingOrigins,
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
    NutritionDocuments,
    ProgressPhotos,
    DataSpaces,
    MigrationState,
    SyncMetadata,
    SyncOutbox,
    SyncCheckpoints,
    SyncAppliedChanges,
    PhotoFileIntents,
  ],
)
class DatabaseService extends _$DatabaseService {
  DatabaseService() : this._(_openConnection());

  DatabaseService.inMemory() : this._(NativeDatabase.memory());

  DatabaseService._(super.executor);

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          // Keep each historical schema change in its own gate. Drift runs
          // this callback once for a multi-version upgrade, so range checks
          // ensure that every intermediate change is applied exactly once and
          // in dependency order.
          if (from < 2 && to >= 2) {
            await migrator.createTable(supplementDefinitions);
            await migrator.createTable(supplementLogs);
          }
          if (from < 3 && to >= 3) {
            await _addColumnIfMissing(migrator, weightLogs, weightLogs.source);
          }
          if (from < 4 && to >= 4) {
            await migrator.createTable(barcodeProducts);
          }
          if (from < 5 && to >= 5) {
            await migrator.createTable(recipes);
            await migrator.createTable(customFoods);
            await migrator.createTable(favoriteFoods);
            await migrator.createTable(plannedMeals);
            await migrator.createTable(customPortions);
            await migrator.createTable(recentFoods);
            await migrator.createTable(userStatsTable);
            await migrator.createTable(plannedMealsChecked);
          }
          if (from < 6 && to >= 6) {
            await migrator.createTable(progressPhotos);
          }
          if (from < 7 && to >= 7) {
            await _addColumnIfMissing(
              migrator,
              barcodeProducts,
              barcodeProducts.cacheStatus,
            );
          }
          if (from < 8 && to >= 8) {
            await _addColumnIfMissing(migrator, foods, foods.fiber);
            await _addColumnIfMissing(
              migrator,
              plannedMeals,
              plannedMeals.fiber,
            );
            await _addColumnIfMissing(
              migrator,
              barcodeProducts,
              barcodeProducts.fiberPer100g,
            );
            await _addColumnIfMissing(
              migrator,
              customFoods,
              customFoods.fiberPer100g,
            );
            await _addColumnIfMissing(
              migrator,
              recentFoods,
              recentFoods.fiberPer100g,
            );
          }
          if (from < 9 && to >= 9) {
            await migrator.createTable(nutritionDocuments);
          }
          if (from < 10 && to >= 10) {
            // Existing favorite rows intentionally keep a null snapshot. The
            // nullable column lets the canonical library migration populate
            // snapshots later without losing id-only favorites today.
            await _addColumnIfMissing(
              migrator,
              favoriteFoods,
              favoriteFoods.foodJson,
            );
            await migrator.createTable(dataSpaces);
            await migrator.createTable(migrationState);
            await migrator.createTable(syncMetadata);
            await migrator.createTable(syncOutbox);
            await migrator.createTable(syncCheckpoints);
            await migrator.createTable(syncAppliedChanges);
            await migrator.createTable(photoFileIntents);
            await _createVersion10Indexes();
          }
          if (from < 11 && to >= 11) {
            // v10 did not declare the supplement relationship. Remove any
            // historical orphan rows before Drift recreates the table with a
            // real foreign-key constraint.
            await customStatement(
              'DELETE FROM supplement_logs '
              'WHERE supplement_id NOT IN '
              '(SELECT id FROM supplement_definitions)',
            );
            await migrator.alterTable(TableMigration(supplementLogs));
          }
          if (from < 12 && to >= 12) {
            await _addColumnIfMissing(migrator, foods, foods.sourceFoodId);
            await _addColumnIfMissing(migrator, foods, foods.portionAmount);
            await _addColumnIfMissing(migrator, foods, foods.portionUnit);
            await _addColumnIfMissing(migrator, foods, foods.portionLabel);
            await _addColumnIfMissing(migrator, foods, foods.portionQuantity);
            await _addColumnIfMissing(
              migrator,
              barcodeProducts,
              barcodeProducts.nutritionUnit,
            );
            await _addColumnIfMissing(
              migrator,
              customFoods,
              customFoods.nutritionUnit,
            );
            await _addColumnIfMissing(
              migrator,
              recentFoods,
              recentFoods.nutritionUnit,
            );
            await _addColumnIfMissing(
              migrator,
              customPortions,
              customPortions.unit,
            );
            await _addColumnIfMissing(
              migrator,
              customPortions,
              customPortions.displayLabel,
            );
            await _addColumnIfMissing(
              migrator,
              customPortions,
              customPortions.displayQuantity,
            );
          }
          if (from < 13 && to >= 13) {
            await migrator.createTable(foodSharingOrigins);
            await customStatement(
              'CREATE INDEX IF NOT EXISTS food_sharing_origins_sequence_idx ON food_sharing_origins (sequence)',
            );
            // Existing rows intentionally have no eligible logging origin.
            // Editing or backdating them later must not upload diary history.
          }
        },
        beforeOpen: (_) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _addColumnIfMissing(
    Migrator migrator,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    final rows = await customSelect(
      'PRAGMA table_info("${table.actualTableName}")',
    ).get();
    final columnExists = rows.any(
      (row) => row.read<String>('name') == column.name,
    );
    if (!columnExists) {
      await migrator.addColumn(table, column);
    }
  }

  Future<void> _createVersion10Indexes() async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS foods_timestamp_idx ON foods (timestamp DESC, id ASC)',
      'CREATE INDEX IF NOT EXISTS water_logs_timestamp_idx ON water_logs (timestamp DESC, id ASC)',
      'CREATE INDEX IF NOT EXISTS weight_logs_timestamp_idx ON weight_logs (timestamp DESC, id ASC)',
      'CREATE INDEX IF NOT EXISTS workout_logs_timestamp_idx ON workout_logs (timestamp DESC, id ASC)',
      'CREATE INDEX IF NOT EXISTS supplement_logs_timestamp_idx ON supplement_logs (timestamp DESC, id ASC)',
      'CREATE INDEX IF NOT EXISTS barcode_products_expiry_idx ON barcode_products (cache_status ASC, cached_at ASC)',
      'CREATE INDEX IF NOT EXISTS recipes_created_at_idx ON recipes (created_at DESC, id ASC)',
      'CREATE INDEX IF NOT EXISTS planned_meals_schedule_idx ON planned_meals (date ASC, meal ASC, id ASC)',
      'CREATE INDEX IF NOT EXISTS custom_portions_product_idx ON custom_portions (product_key ASC, created_at ASC, id ASC)',
      'CREATE INDEX IF NOT EXISTS progress_photos_category_timestamp_idx ON progress_photos (category ASC, timestamp DESC, id ASC)',
      'CREATE INDEX IF NOT EXISTS sync_metadata_space_entity_idx ON sync_metadata (data_space_id ASC, entity_type ASC, entity_id ASC)',
      'CREATE INDEX IF NOT EXISTS sync_metadata_pending_idx ON sync_metadata (data_space_id ASC, updated_at DESC)',
      'CREATE INDEX IF NOT EXISTS sync_outbox_pending_idx ON sync_outbox (data_space_id ASC, processed_at ASC, created_at ASC)',
      'CREATE INDEX IF NOT EXISTS sync_outbox_entity_idx ON sync_outbox (data_space_id ASC, entity_type ASC, entity_id ASC)',
      'CREATE INDEX IF NOT EXISTS sync_applied_changes_entity_idx ON sync_applied_changes (data_space_id ASC, entity_type ASC, entity_id ASC)',
      'CREATE INDEX IF NOT EXISTS photo_file_intents_pending_idx ON photo_file_intents (data_space_id ASC, processed_at ASC, created_at ASC)',
      'CREATE INDEX IF NOT EXISTS photo_file_intents_photo_idx ON photo_file_intents (data_space_id ASC, photo_id ASC)',
    ];
    for (final statement in statements) {
      await customStatement(statement);
    }
  }

  // ---------------------------------------------------------------------------
  // FOODS
  // ---------------------------------------------------------------------------

  Future<List<FoodEntry>> getAllFoods() async {
    final rows = await (select(foods)
          ..orderBy([
            (t) => OrderingTerm.desc(t.timestamp),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
    return rows
        .map(
          (row) => FoodEntry(
            id: row.id,
            name: row.name,
            calories: row.calories,
            protein: row.protein,
            carbs: row.carbs,
            fat: row.fat,
            fiber: row.fiber,
            timestamp: row.timestamp,
            meal: row.meal,
            sourceFoodId: row.sourceFoodId,
            portionAmount: row.portionAmount,
            portionUnit: row.portionUnit == null
                ? null
                : NutritionUnitX.fromStorage(row.portionUnit),
            portionLabel: row.portionLabel,
            portionQuantity: row.portionQuantity,
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
        fiber: Value(entry.fiber),
        timestamp: Value(entry.timestamp),
        meal: Value(entry.meal),
        sourceFoodId: Value(entry.sourceFoodId),
        portionAmount: Value(entry.portionAmount),
        portionUnit: Value(entry.portionUnit?.storageValue),
        portionLabel: Value(entry.portionLabel),
        portionQuantity: Value(entry.portionQuantity),
      ),
    );
  }

  Future<void> upsertFood(FoodEntry entry) async {
    await into(foods).insertOnConflictUpdate(
      FoodsCompanion(
        id: Value(entry.id),
        name: Value(entry.name),
        calories: Value(entry.calories),
        protein: Value(entry.protein),
        carbs: Value(entry.carbs),
        fat: Value(entry.fat),
        fiber: Value(entry.fiber),
        timestamp: Value(entry.timestamp),
        meal: Value(entry.meal),
        sourceFoodId: Value(entry.sourceFoodId),
        portionAmount: Value(entry.portionAmount),
        portionUnit: Value(entry.portionUnit?.storageValue),
        portionLabel: Value(entry.portionLabel),
        portionQuantity: Value(entry.portionQuantity),
      ),
    );
  }

  Future<FoodSharingOriginRow> recordFoodSharingOrigin(
    String foodId, {
    required bool deleted,
    required DateTime now,
  }) async {
    final prior = await (select(foodSharingOrigins)
          ..where((row) => row.foodId.equals(foodId)))
        .getSingleOrNull();
    final existing = await (select(foods)
          ..where((row) => row.id.equals(foodId)))
        .getSingleOrNull();
    final sequenceRows = await customSelect(
      'SELECT COALESCE(MAX(sequence), 0) + 1 AS next_sequence FROM food_sharing_origins',
    ).getSingle();
    final milliseconds = now.toUtc().millisecondsSinceEpoch;
    final original = prior == null
        ? (existing == null && !deleted ? milliseconds : null)
        : (prior.deletedAt != null && existing != null
            ? null
            : prior.originallyLoggedAt);
    final row = FoodSharingOriginRow(
      foodId: foodId,
      originallyLoggedAt: original,
      changedAt: milliseconds,
      revision: (prior?.revision ?? 0) + 1,
      sequence: sequenceRows.read<int>('next_sequence'),
      deletedAt: deleted ? milliseconds : null,
    );
    await into(foodSharingOrigins).insertOnConflictUpdate(
      FoodSharingOriginsCompanion(
        foodId: Value(row.foodId),
        originallyLoggedAt: Value(row.originallyLoggedAt),
        changedAt: Value(row.changedAt),
        revision: Value(row.revision),
        sequence: Value(row.sequence),
        deletedAt: Value(row.deletedAt),
      ),
    );
    return row;
  }

  Future<List<FoodSharingOriginRow>> foodSharingChanges({
    required int afterSequence,
    int limit = 100,
  }) =>
      (select(foodSharingOrigins)
            ..where((row) => row.sequence.isBiggerThanValue(afterSequence))
            ..orderBy([(row) => OrderingTerm.asc(row.sequence)])
            ..limit(limit))
          .get();

  Future<void> _markFoodSharingOriginsDeleted() async {
    final rows = await (select(foodSharingOrigins)
          ..where((row) => row.deletedAt.isNull()))
        .get();
    final now = DateTime.now().toUtc();
    for (final row in rows) {
      await recordFoodSharingOrigin(row.foodId, deleted: true, now: now);
    }
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
              fiber: Value(entry.fiber),
              timestamp: Value(entry.timestamp),
              meal: Value(entry.meal),
              sourceFoodId: Value(entry.sourceFoodId),
              portionAmount: Value(entry.portionAmount),
              portionUnit: Value(entry.portionUnit?.storageValue),
              portionLabel: Value(entry.portionLabel),
              portionQuantity: Value(entry.portionQuantity),
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
        fiber: Value(entry.fiber),
        timestamp: Value(entry.timestamp),
        meal: Value(entry.meal),
        sourceFoodId: Value(entry.sourceFoodId),
        portionAmount: Value(entry.portionAmount),
        portionUnit: Value(entry.portionUnit?.storageValue),
        portionLabel: Value(entry.portionLabel),
        portionQuantity: Value(entry.portionQuantity),
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
    final rows = await (select(waterLogs)
          ..orderBy([
            (t) => OrderingTerm.desc(t.timestamp),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
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

  Future<void> upsertWater(WaterEntry entry) async {
    await into(waterLogs).insertOnConflictUpdate(
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
    final rows = await (select(weightLogs)
          ..orderBy([
            (t) => OrderingTerm.desc(t.timestamp),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
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

  Future<void> upsertWeight(WeightEntry entry) async {
    await into(weightLogs).insertOnConflictUpdate(
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
    final rows = await (select(workoutLogs)
          ..orderBy([
            (t) => OrderingTerm.desc(t.timestamp),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
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

  Future<void> upsertWorkout(WorkoutEntry entry) async {
    await into(workoutLogs).insertOnConflictUpdate(
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
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.id),
          ]))
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

  Future<void> upsertSupplement(Supplement supplement) async {
    await into(supplementDefinitions).insertOnConflictUpdate(
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

  Future<int> deleteSupplement(String id, {bool transactional = true}) async {
    Future<int> deleteAll() async {
      await (delete(supplementLogs)..where((t) => t.supplementId.equals(id)))
          .go();
      return (delete(supplementDefinitions)..where((t) => t.id.equals(id)))
          .go();
    }

    if (transactional) return transaction(deleteAll);
    return deleteAll();
  }

  // ---------------------------------------------------------------------------
  // SUPPLEMENT LOGS
  // ---------------------------------------------------------------------------

  Future<List<SupplementLogEntry>> getAllSupplementLogs() async {
    final rows = await (select(supplementLogs)
          ..orderBy([
            (t) => OrderingTerm.desc(t.timestamp),
            (t) => OrderingTerm.asc(t.id),
          ]))
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
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.timestamp),
            (t) => OrderingTerm.asc(t.id),
          ]))
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
    final foundCutoff = DateTime.now().subtract(const Duration(days: 30));
    final partialCutoff = DateTime.now().subtract(const Duration(days: 14));
    final notFoundCutoff = DateTime.now().subtract(const Duration(days: 7));

    await (delete(barcodeProducts)
          ..where(
            (t) =>
                t.isUserCorrected.equals(false) &
                (t.cacheStatus.equals('found') &
                        t.cachedAt.isSmallerThanValue(foundCutoff) |
                    t.cacheStatus.equals('partial') &
                        t.cachedAt.isSmallerThanValue(partialCutoff) |
                    t.cacheStatus.equals('notFound') &
                        t.cachedAt.isSmallerThanValue(notFoundCutoff)),
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

  Future<void> deleteAllData({bool transactional = true}) async {
    Future<void> deleteAll() async {
      await _deleteNutritionData();
      await delete(supplementLogs).go();
      await delete(supplementDefinitions).go();
      await delete(barcodeProducts).go();
      await _deleteSyncState();
      await delete(photoFileIntents).go();
    }

    if (transactional) {
      await transaction(deleteAll);
    } else {
      await deleteAll();
    }
  }

  Future<void> deleteNutritionData({bool transactional = true}) async {
    if (transactional) {
      await transaction(_deleteNutritionData);
    } else {
      await _deleteNutritionData();
    }
  }

  Future<void> clearSyncState({bool transactional = true}) async {
    if (transactional) {
      await transaction(_deleteSyncState);
    } else {
      await _deleteSyncState();
    }
  }

  Future<void> _deleteSyncState() async {
    await delete(syncMetadata).go();
    await delete(syncOutbox).go();
    await delete(syncCheckpoints).go();
    await delete(syncAppliedChanges).go();
  }

  Future<void> _deleteNutritionData() async {
    await _markFoodSharingOriginsDeleted();
    await delete(foods).go();
    await delete(waterLogs).go();
    await delete(weightLogs).go();
    await delete(workoutLogs).go();
    await delete(recipes).go();
    await delete(customFoods).go();
    await delete(favoriteFoods).go();
    await delete(plannedMeals).go();
    await delete(customPortions).go();
    await delete(recentFoods).go();
    await delete(userStatsTable).go();
    await delete(plannedMealsChecked).go();
    await delete(nutritionDocuments).go();
    await delete(progressPhotos).go();
  }

  // ---------------------------------------------------------------------------
  // CANONICAL NUTRITION DOCUMENTS
  // ---------------------------------------------------------------------------

  Future<String?> readNutritionDocument(String key) async {
    final row = await (select(nutritionDocuments)
          ..where((document) => document.key.equals(key)))
        .getSingleOrNull();
    return row?.json;
  }

  Future<void> writeNutritionDocument(String key, String json) async {
    await into(nutritionDocuments).insertOnConflictUpdate(
      NutritionDocumentsCompanion(
        key: Value(key),
        json: Value(json),
      ),
    );
  }

  Future<void> writeNutritionDocuments(Map<String, String> documents) async {
    await transaction(() async {
      for (final entry in documents.entries) {
        await writeNutritionDocument(entry.key, entry.value);
      }
    });
  }

  Future<void> deleteNutritionDocument(String key) async {
    await (delete(nutritionDocuments)
          ..where((document) => document.key.equals(key)))
        .go();
  }

  // ---------------------------------------------------------------------------
  // MIGRATION AND SYNC METADATA
  // ---------------------------------------------------------------------------

  static const defaultDataSpaceId = 'local';

  Future<MigrationStateRow?> getMigrationState(String key) {
    return (select(migrationState)..where((row) => row.key.equals(key)))
        .getSingleOrNull();
  }

  Future<void> setMigrationState(
    String key, {
    required int version,
    String? checksum,
    DateTime? updatedAt,
  }) async {
    await into(migrationState).insertOnConflictUpdate(
      MigrationStateCompanion(
        key: Value(key),
        version: Value(version),
        updatedAt: Value((updatedAt ?? DateTime.now()).toUtc()),
        checksum: Value(checksum),
      ),
    );
  }

  Future<DataSpaceRow> ensureDefaultDataSpace({DateTime? now}) async {
    final existing = await (select(dataSpaces)
          ..where((space) => space.id.equals(defaultDataSpaceId)))
        .getSingleOrNull();
    if (existing != null) return existing;

    final timestamp = (now ?? DateTime.now()).toUtc();
    final row = DataSpaceRow(
      id: defaultDataSpaceId,
      name: 'Local device',
      isDefault: true,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    await into(dataSpaces).insert(row);
    return row;
  }

  Future<SyncMetadataRow?> getSyncMetadata(
    String entityType,
    String entityId, {
    String dataSpaceId = defaultDataSpaceId,
  }) {
    return (select(syncMetadata)
          ..where(
            (row) =>
                row.dataSpaceId.equals(dataSpaceId) &
                row.entityType.equals(entityType) &
                row.entityId.equals(entityId),
          ))
        .getSingleOrNull();
  }

  /// Records one local mutation and compacts any older pending mutation for
  /// the same entity. Callers invoke this inside their enclosing transaction.
  Future<SyncMetadataRow> recordLocalMutation({
    required String entityType,
    required String entityId,
    required String operation,
    String? payloadJson,
    String dataSpaceId = defaultDataSpaceId,
    DateTime? now,
  }) async {
    await ensureDefaultDataSpace(now: now);
    final timestamp = (now ?? DateTime.now()).toUtc();
    final previous = await getSyncMetadata(
      entityType,
      entityId,
      dataSpaceId: dataSpaceId,
    );
    final revision = (previous?.localRevision ?? 0) + 1;
    final deletedAt = operation == 'delete' ? timestamp : null;
    final metadata = SyncMetadataRow(
      dataSpaceId: dataSpaceId,
      entityType: entityType,
      entityId: entityId,
      localRevision: revision,
      updatedAt: timestamp,
      deletedAt: deletedAt,
      remoteVersion: null,
    );

    await into(syncMetadata).insertOnConflictUpdate(metadata);
    await (delete(syncOutbox)
          ..where(
            (row) =>
                row.dataSpaceId.equals(dataSpaceId) &
                row.entityType.equals(entityType) &
                row.entityId.equals(entityId) &
                row.processedAt.isNull(),
          ))
        .go();
    await into(syncOutbox).insert(
      SyncOutboxCompanion.insert(
        id: jsonEncode(<Object?>[
          'nutrition-sync-v1',
          dataSpaceId,
          entityType,
          entityId,
          revision,
        ]),
        dataSpaceId: dataSpaceId,
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payloadJson: Value(payloadJson),
        baseRevision: Value(previous?.localRevision),
        createdAt: timestamp,
      ),
    );
    return metadata;
  }

  Future<List<SyncOutboxRow>> getPendingSyncOutbox({
    String dataSpaceId = defaultDataSpaceId,
    int limit = 100,
    DateTime? now,
  }) {
    final current = (now ?? DateTime.now()).toUtc();
    return (select(syncOutbox)
          ..where(
            (row) =>
                row.dataSpaceId.equals(dataSpaceId) &
                row.processedAt.isNull() &
                (row.nextAttemptAt.isNull() |
                    row.nextAttemptAt.isSmallerOrEqualValue(current)),
          )
          ..orderBy([
            (row) => OrderingTerm.asc(row.createdAt),
            (row) => OrderingTerm.asc(row.id),
          ])
          ..limit(limit))
        .get();
  }

  Future<void> markSyncOutboxAttempt(
    String id, {
    required int attempts,
    DateTime? nextAttemptAt,
    String? error,
  }) async {
    await (update(syncOutbox)..where((row) => row.id.equals(id))).write(
      SyncOutboxCompanion(
        attempts: Value(attempts),
        nextAttemptAt: Value(nextAttemptAt?.toUtc()),
        lastError: Value(error),
      ),
    );
  }

  Future<void> markSyncOutboxProcessed(
    String id, {
    DateTime? processedAt,
  }) async {
    await (update(syncOutbox)..where((row) => row.id.equals(id))).write(
      SyncOutboxCompanion(
        processedAt: Value((processedAt ?? DateTime.now()).toUtc()),
        nextAttemptAt: const Value(null),
        lastError: const Value(null),
      ),
    );
  }

  Future<void> pruneProcessedSyncOutbox({
    Duration olderThan = const Duration(days: 30),
    DateTime? now,
  }) async {
    final cutoff = (now ?? DateTime.now()).toUtc().subtract(olderThan);
    await (delete(syncOutbox)
          ..where(
            (row) =>
                row.processedAt.isNotNull() &
                row.processedAt.isSmallerOrEqualValue(cutoff),
          ))
        .go();
  }

  // ---------------------------------------------------------------------------
  // RECIPES
  // ---------------------------------------------------------------------------

  Future<List<RecipeRow>> getAllRecipes() async {
    return (select(recipes)
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
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

  Future<void> upsertRecipe(RecipeRow recipe) async {
    await into(recipes).insertOnConflictUpdate(
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

  Future<void> replaceRecipes(
    List<RecipeRow> rows, {
    bool transactional = true,
  }) async {
    Future<void> write() async {
      await delete(recipes).go();
      await batch((batch) {
        batch.insertAll(recipes, rows, mode: InsertMode.insertOrReplace);
      });
    }

    if (transactional) {
      await transaction(write);
    } else {
      await write();
    }
  }

  // ---------------------------------------------------------------------------
  // CUSTOM FOODS
  // ---------------------------------------------------------------------------

  Future<List<CustomFoodRow>> getAllCustomFoods() async {
    return (select(customFoods)..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
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
        fiberPer100g: Value(food.fiberPer100g),
        nutritionUnit: Value(food.nutritionUnit),
        barcode: Value(food.barcode),
        brand: Value(food.brand),
        imageUrl: Value(food.imageUrl),
        servingsJson: Value(food.servingsJson),
      ),
    );
  }

  Future<void> upsertCustomFood(CustomFoodRow food) async {
    await into(customFoods).insertOnConflictUpdate(
      CustomFoodsCompanion(
        id: Value(food.id),
        name: Value(food.name),
        category: Value(food.category),
        caloriesPer100g: Value(food.caloriesPer100g),
        proteinPer100g: Value(food.proteinPer100g),
        carbsPer100g: Value(food.carbsPer100g),
        fatPer100g: Value(food.fatPer100g),
        fiberPer100g: Value(food.fiberPer100g),
        nutritionUnit: Value(food.nutritionUnit),
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
                fiberPer100g: Value(f.fiberPer100g),
                nutritionUnit: Value(f.nutritionUnit),
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

  Future<void> replaceCustomFoods(
    List<CustomFoodRow> rows, {
    bool transactional = true,
  }) async {
    Future<void> write() async {
      await delete(customFoods).go();
      await batch((batch) {
        batch.insertAll(customFoods, rows, mode: InsertMode.insertOrReplace);
      });
    }

    if (transactional) {
      await transaction(write);
    } else {
      await write();
    }
  }

  // ---------------------------------------------------------------------------
  // FAVORITE FOODS
  // ---------------------------------------------------------------------------

  Future<List<FavoriteFoodRow>> getAllFavoriteFoods() async {
    return (select(favoriteFoods)..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
  }

  Future<int> insertFavoriteFood(FavoriteFoodRow food) {
    return into(favoriteFoods).insert(
      FavoriteFoodsCompanion(
        id: Value(food.id),
        foodJson: Value(food.foodJson),
      ),
    );
  }

  Future<void> upsertFavoriteFood(FavoriteFoodRow food) async {
    await into(favoriteFoods).insertOnConflictUpdate(
      FavoriteFoodsCompanion(
        id: Value(food.id),
        foodJson: Value(food.foodJson),
      ),
    );
  }

  Future<int> deleteFavoriteFood(String id) {
    return (delete(favoriteFoods)..where((t) => t.id.equals(id))).go();
  }

  Future<void> replaceFavoriteFoods(
    List<FavoriteFoodRow> rows, {
    bool transactional = true,
  }) async {
    Future<void> write() async {
      await delete(favoriteFoods).go();
      await batch((batch) {
        batch.insertAll(favoriteFoods, rows, mode: InsertMode.insertOrReplace);
      });
    }

    if (transactional) {
      await transaction(write);
    } else {
      await write();
    }
  }

  // ---------------------------------------------------------------------------
  // PLANNED MEALS
  // ---------------------------------------------------------------------------

  Future<List<PlannedMealRow>> getAllPlannedMeals() async {
    return (select(plannedMeals)
          ..orderBy([
            (t) => OrderingTerm.asc(t.date),
            (t) => OrderingTerm.asc(t.meal),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
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
        fiber: Value(meal.fiber),
        recipeId: Value(meal.recipeId),
        servings: Value(meal.servings),
        ingredientsJson: Value(meal.ingredientsJson),
      ),
    );
  }

  Future<void> upsertPlannedMeal(PlannedMealRow meal) async {
    await into(plannedMeals).insertOnConflictUpdate(
      PlannedMealsCompanion(
        id: Value(meal.id),
        date: Value(meal.date),
        meal: Value(meal.meal),
        name: Value(meal.name),
        calories: Value(meal.calories),
        protein: Value(meal.protein),
        carbs: Value(meal.carbs),
        fat: Value(meal.fat),
        fiber: Value(meal.fiber),
        recipeId: Value(meal.recipeId),
        servings: Value(meal.servings),
        ingredientsJson: Value(meal.ingredientsJson),
      ),
    );
  }

  Future<void> upsertPlannedMeals(List<PlannedMealRow> rows) async {
    if (rows.isEmpty) return;
    await batch((batch) {
      batch.insertAll(
        plannedMeals,
        rows
            .map(
              (meal) => PlannedMealsCompanion(
                id: Value(meal.id),
                date: Value(meal.date),
                meal: Value(meal.meal),
                name: Value(meal.name),
                calories: Value(meal.calories),
                protein: Value(meal.protein),
                carbs: Value(meal.carbs),
                fat: Value(meal.fat),
                fiber: Value(meal.fiber),
                recipeId: Value(meal.recipeId),
                servings: Value(meal.servings),
                ingredientsJson: Value(meal.ingredientsJson),
              ),
            )
            .toList(),
        mode: InsertMode.insertOrReplace,
      );
    });
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
                fiber: Value(m.fiber),
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

  Future<void> replacePlannedMeals(
    List<PlannedMealRow> rows, {
    bool transactional = true,
  }) async {
    Future<void> write() async {
      await delete(plannedMeals).go();
      await batch((batch) {
        batch.insertAll(plannedMeals, rows, mode: InsertMode.insertOrReplace);
      });
    }

    if (transactional) {
      await transaction(write);
    } else {
      await write();
    }
  }

  // ---------------------------------------------------------------------------

  Future<List<CustomPortionRow>> getAllCustomPortions() async {
    return (select(customPortions)
          ..orderBy([
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  Future<int> insertCustomPortion(CustomPortionRow portion) {
    return into(customPortions).insert(
      CustomPortionsCompanion(
        id: Value(portion.id),
        productKey: Value(portion.productKey),
        name: Value(portion.name),
        grams: Value(portion.grams),
        unit: Value(portion.unit),
        displayLabel: Value(portion.displayLabel),
        displayQuantity: Value(portion.displayQuantity),
        createdAt: Value(portion.createdAt),
      ),
    );
  }

  Future<void> upsertCustomPortion(CustomPortionRow portion) async {
    await into(customPortions).insertOnConflictUpdate(
      CustomPortionsCompanion(
        id: Value(portion.id),
        productKey: Value(portion.productKey),
        name: Value(portion.name),
        grams: Value(portion.grams),
        unit: Value(portion.unit),
        displayLabel: Value(portion.displayLabel),
        displayQuantity: Value(portion.displayQuantity),
        createdAt: Value(portion.createdAt),
      ),
    );
  }

  Future<int> deleteCustomPortion(String id) {
    return (delete(customPortions)..where((t) => t.id.equals(id))).go();
  }

  Future<void> replaceCustomPortions(
    List<CustomPortionRow> rows, {
    bool transactional = true,
  }) async {
    Future<void> write() async {
      await delete(customPortions).go();
      await batch((batch) {
        batch.insertAll(customPortions, rows, mode: InsertMode.insertOrReplace);
      });
    }

    if (transactional) {
      await transaction(write);
    } else {
      await write();
    }
  }

  // ---------------------------------------------------------------------------
  // RECENT FOODS
  // ---------------------------------------------------------------------------

  Future<List<RecentFoodRow>> getAllRecentFoods() async {
    return (select(recentFoods)..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
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
                fiberPer100g: Value(f.fiberPer100g),
                nutritionUnit: Value(f.nutritionUnit),
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
    return (select(userStatsTable)
          ..where((stats) => stats.id.equals('default')))
        .getSingleOrNull();
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

  Future<List<String>> getPlannedMealsChecked() async {
    final rows = await (select(plannedMealsChecked)
          ..orderBy([(t) => OrderingTerm.asc(t.key)]))
        .get();
    return rows.map((row) => row.key).toList();
  }

  Future<void> replacePlannedMealsChecked(
    List<String> keys, {
    bool transactional = true,
  }) async {
    Future<void> write() async {
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

    if (transactional) {
      await transaction(write);
    } else {
      await write();
    }
  }

  // ---------------------------------------------------------------------------
  // PROGRESS PHOTOS
  // ---------------------------------------------------------------------------

  Future<List<ProgressPhoto>> getAllPhotos() async {
    final rows = await (select(progressPhotos)
          ..orderBy([
            (t) => OrderingTerm.desc(t.timestamp),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
    return rows
        .map(
          (row) => ProgressPhoto(
            id: row.id,
            imagePath: row.imagePath,
            timestamp: row.timestamp,
            weightKg: row.weightKg,
            note: row.note,
            category: PhotoCategory.values[row.category],
            createdAt: row.createdAt,
          ),
        )
        .toList();
  }

  Future<int> insertPhoto(ProgressPhoto photo) {
    return into(progressPhotos).insert(
      ProgressPhotosCompanion(
        id: Value(photo.id),
        imagePath: Value(photo.imagePath),
        timestamp: Value(photo.timestamp),
        weightKg: Value(photo.weightKg),
        note: Value(photo.note),
        category: Value(photo.category.index),
        createdAt: Value(photo.createdAt),
      ),
    );
  }

  Future<void> upsertPhoto(ProgressPhoto photo) async {
    await into(progressPhotos).insertOnConflictUpdate(
      ProgressPhotosCompanion(
        id: Value(photo.id),
        imagePath: Value(photo.imagePath),
        timestamp: Value(photo.timestamp),
        weightKg: Value(photo.weightKg),
        note: Value(photo.note),
        category: Value(photo.category.index),
        createdAt: Value(photo.createdAt),
      ),
    );
  }

  Future<void> insertPhotos(List<ProgressPhoto> photos) async {
    await batch((batch) {
      batch.insertAll(
        progressPhotos,
        photos.map(
          (photo) => ProgressPhotosCompanion(
            id: Value(photo.id),
            imagePath: Value(photo.imagePath),
            timestamp: Value(photo.timestamp),
            weightKg: Value(photo.weightKg),
            note: Value(photo.note),
            category: Value(photo.category.index),
            createdAt: Value(photo.createdAt),
          ),
        ),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<int> deletePhoto(String id) {
    return (delete(progressPhotos)..where((t) => t.id.equals(id))).go();
  }

  Future<ProgressPhoto?> getPhotoById(String id) async {
    final row = await (select(progressPhotos)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return ProgressPhoto(
      id: row.id,
      imagePath: row.imagePath,
      timestamp: row.timestamp,
      weightKg: row.weightKg,
      note: row.note,
      category: PhotoCategory.values[row.category],
      createdAt: row.createdAt,
    );
  }

  Future<List<ProgressPhoto>> getPhotosByCategory(
    PhotoCategory category,
  ) async {
    final rows = await (select(progressPhotos)
          ..where((t) => t.category.equals(category.index))
          ..orderBy([
            (t) => OrderingTerm.desc(t.timestamp),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
    return rows
        .map(
          (row) => ProgressPhoto(
            id: row.id,
            imagePath: row.imagePath,
            timestamp: row.timestamp,
            weightKg: row.weightKg,
            note: row.note,
            category: PhotoCategory.values[row.category],
            createdAt: row.createdAt,
          ),
        )
        .toList();
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
        fiberPer100g: Value(food.fiberPer100g),
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
                fiberPer100g: Value(f.fiberPer100g),
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
        fiber: Value(meal.fiber),
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
                fiber: Value(m.fiber),
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
                unit: Value(p.unit.storageValue),
                displayLabel: Value(p.label),
                displayQuantity: Value(p.quantity),
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
              fiberPer100g: f.fiberPer100g,
              nutritionUnit: f.nutritionUnit.storageValue,
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
    return NativeDatabase.createInBackground(
      file,
      setup: _configureSqlite,
    );
  });
}

void _configureSqlite(dynamic database) {
  // The callback is sent to Drift's background isolate; keeping the raw
  // sqlite type out of this library avoids coupling the domain layer to a
  // transitive FFI package.
  // ignore: avoid_dynamic_calls
  database.execute('PRAGMA journal_mode = WAL');
  // ignore: avoid_dynamic_calls
  database.execute('PRAGMA synchronous = FULL');
  // ignore: avoid_dynamic_calls
  database.execute('PRAGMA foreign_keys = ON');
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
