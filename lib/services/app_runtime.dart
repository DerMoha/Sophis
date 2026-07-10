import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/providers/settings_provider.dart';
import 'package:sophis/providers/supplements_provider.dart';
import 'package:sophis/services/barcode_lookup_service.dart';
import 'package:sophis/services/brocade_service.dart';
import 'package:sophis/services/database_service.dart';
import 'package:sophis/services/notification_service.dart';
import 'package:sophis/services/openfoodfacts_service.dart';
import 'package:sophis/services/storage_service.dart';

/// Owns the initialized dependencies and lifecycle of one app run.
class AppRuntime {
  final StorageService storage;
  final DatabaseService database;
  final NotificationService notifications;
  final SettingsProvider settings;
  final NutritionProvider nutrition;
  final SupplementsProvider supplements;
  final BarcodeLookupService barcodeLookup;

  AppRuntime._({
    required this.storage,
    required this.database,
    required this.notifications,
    required this.settings,
    required this.nutrition,
    required this.supplements,
    required this.barcodeLookup,
  });

  static Future<AppRuntime> initialize() async {
    DatabaseService? database;
    try {
      final storage = await StorageService.create();
      final notifications = NotificationService();
      await notifications.initialize();

      database = DatabaseService();
      final settings = SettingsProvider(
        storage,
        notificationService: notifications,
      );
      await settings.initialize();

      final nutrition = NutritionProvider(storage, database);
      nutrition.attachSettingsProvider(settings);
      await nutrition.initialize();

      final supplements = SupplementsProvider(database, notifications);
      await supplements.initialize();

      final barcodeLookup = BarcodeLookupService(
        db: database,
        offService: OpenFoodFactsService(),
        brocadeService: BrocadeService(),
      );
      await barcodeLookup.cleanExpiredCache();

      return AppRuntime._(
        storage: storage,
        database: database,
        notifications: notifications,
        settings: settings,
        nutrition: nutrition,
        supplements: supplements,
        barcodeLookup: barcodeLookup,
      );
    } catch (_) {
      await database?.close();
      rethrow;
    }
  }

  Future<void> dispose() async {
    settings.dispose();
    nutrition.dispose();
    supplements.dispose();
    await database.close();
  }
}
