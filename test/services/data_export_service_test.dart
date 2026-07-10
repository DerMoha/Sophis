import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/nutrition_backup.dart';
import 'package:sophis/models/progress_photo.dart';
import 'package:sophis/models/user_stats.dart';
import 'package:sophis/services/data_export_service.dart';

void main() {
  group('DataExportService archive codec', () {
    test('round-tripped complete records and progress photo bytes', () async {
      final directory = await Directory.systemTemp.createTemp('sophis-backup');
      addTearDown(() => directory.delete(recursive: true));
      final photoFile = File('${directory.path}/photo.jpg');
      await photoFile.writeAsBytes([1, 2, 3, 4]);
      final timestamp = DateTime(2026, 1, 2, 8, 30);
      const recent = FoodItem(
        id: 'recent-1',
        name: 'Yogurt',
        category: 'dairy',
        caloriesPer100g: 80,
        proteinPer100g: 9,
        carbsPer100g: 4,
        fatPer100g: 2,
      );
      final backup = _emptyBackup(
        foodEntries: [
          FoodEntry(
            id: 'entry-1',
            name: 'Yogurt',
            calories: 120,
            protein: 12,
            carbs: 6,
            fat: 3,
            timestamp: timestamp,
            meal: 'breakfast',
          ),
        ],
        recentFoods: const [recent],
        recentFoodMeals: const {'recent-1': 'breakfast'},
        progressPhotos: [
          ProgressPhoto(
            id: 'photo-1',
            imagePath: photoFile.path,
            timestamp: timestamp,
            createdAt: timestamp,
          ),
        ],
      );

      final bytes = await DataExportService.buildArchive(backup);
      final decoded = DataExportService.decodeArchive(bytes);

      expect(decoded.backup.foodEntries.single.id, 'entry-1');
      expect(decoded.backup.recentFoods.single.name, 'Yogurt');
      expect(decoded.backup.recentFoodMeals['recent-1'], 'breakfast');
      expect(
        decoded.backup.progressPhotos.single.imagePath,
        'photos/photo-1.jpg',
      );
      expect(decoded.photos['photo-1'], [1, 2, 3, 4]);
    });

    test('rejected malformed and unsupported archives before restore', () {
      expect(
        () => DataExportService.decodeArchive([1, 2, 3]),
        throwsA(anything),
      );

      final archive = Archive()
        ..addFile(
          ArchiveFile.string(
            'manifest.json',
            jsonEncode({'version': 999}),
          ),
        );
      final bytes = ZipEncoder().encodeBytes(archive);
      expect(
        () => DataExportService.decodeArchive(bytes),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

NutritionBackup _emptyBackup({
  List<FoodEntry> foodEntries = const [],
  List<FoodItem> recentFoods = const [],
  Map<String, String> recentFoodMeals = const {},
  List<ProgressPhoto> progressPhotos = const [],
}) =>
    NutritionBackup(
      goals: null,
      profile: null,
      foodEntries: foodEntries,
      waterEntries: const [],
      weightEntries: const [],
      workoutEntries: const [],
      recipes: const [],
      plannedMeals: const [],
      customFoods: const [],
      favoriteFoods: const [],
      customPortions: const [],
      recentFoods: recentFoods,
      recentFoodMeals: recentFoodMeals,
      userStats: const UserStats(),
      shoppingListChecked: const {},
      progressPhotos: progressPhotos,
    );
