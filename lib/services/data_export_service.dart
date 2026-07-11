import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:sophis/models/custom_portion.dart';
import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/food_item.dart';
import 'package:sophis/models/meal_plan.dart';
import 'package:sophis/models/nutrition_backup.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/progress_photo.dart';
import 'package:sophis/models/recipe.dart';
import 'package:sophis/models/user_profile.dart';
import 'package:sophis/models/user_stats.dart';
import 'package:sophis/models/water_entry.dart';
import 'package:sophis/models/weight_entry.dart';
import 'package:sophis/models/workout_entry.dart';
import 'package:sophis/providers/nutrition_provider.dart';
import 'package:sophis/services/service_result.dart';

/// Versioned, self-contained backup archive with validate-before-write restore.
class DataExportService {
  static const int archiveVersion = 2;
  static const int _maxArchiveBytes = 500 * 1024 * 1024;
  static const String _manifestName = 'manifest.json';

  static Future<ServiceResult<void>> exportData(
    NutritionProvider nutrition,
  ) async {
    try {
      final bytes = await buildArchive(nutrition.createBackup());
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final file = File('${tempDir.path}/sophis_backup_$timestamp.zip');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/zip')],
          subject: 'Sophis Data Backup',
        ),
      );
      return const Success(null);
    } catch (e) {
      debugPrint('Export failed: $e');
      return Failure(ServiceErrorType.unknown, 'Export failed: $e');
    }
  }

  static Future<ServiceResult<ImportResult>> importData(
    NutritionProvider nutrition,
  ) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
      if (result == null || result.files.isEmpty) {
        return const Success(
          ImportResult(success: false, message: 'No file selected'),
        );
      }

      final path = result.files.single.path;
      if (path == null) {
        throw const FormatException('Selected backup is not readable');
      }
      return Success(
        await restoreArchive(nutrition, await File(path).readAsBytes()),
      );
    } catch (e) {
      debugPrint('Import failed: $e');
      return Failure(ServiceErrorType.unknown, 'Import failed: $e');
    }
  }

  @visibleForTesting
  static Future<Uint8List> buildArchive(NutritionBackup backup) async {
    final archive = Archive();
    final photoMetadata = <Map<String, dynamic>>[];

    for (final photo in backup.progressPhotos) {
      final image = File(photo.imagePath);
      if (!image.existsSync()) {
        throw StateError('Progress photo is missing: ${photo.id}');
      }
      final imageName = _photoName(photo.id);
      final thumbnailName = _thumbnailName(photo.id);
      archive.addFile(ArchiveFile.bytes(imageName, await image.readAsBytes()));

      final thumbnail = File(
        '${photo.imagePath.replaceAll(RegExp(r'\.jpg$'), '')}_thumb.jpg',
      );
      if (thumbnail.existsSync()) {
        archive.addFile(
          ArchiveFile.bytes(thumbnailName, await thumbnail.readAsBytes()),
        );
      }
      photoMetadata.add(photo.copyWith(imagePath: imageName).toJson());
    }

    final manifest = _encodeManifest(backup, photoMetadata);
    archive.addFile(
      ArchiveFile.string(
        _manifestName,
        const JsonEncoder.withIndent('  ').convert(manifest),
      ),
    );
    return ZipEncoder().encodeBytes(archive);
  }

  @visibleForTesting
  static DecodedBackup decodeArchive(List<int> bytes) {
    if (bytes.length > _maxArchiveBytes) {
      throw const FormatException('Backup exceeds the 500 MB safety limit');
    }
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final manifestFile = archive.find(_manifestName);
    final manifestBytes = manifestFile?.readBytes();
    if (manifestBytes == null) {
      throw const FormatException('Backup manifest is missing');
    }
    final manifest = jsonDecode(utf8.decode(manifestBytes));
    if (manifest is! Map<String, dynamic> ||
        manifest['version'] != archiveVersion) {
      throw const FormatException('Unsupported Sophis backup version');
    }

    final backup = _decodeManifest(manifest);
    final photos = <String, Uint8List>{};
    final thumbnails = <String, Uint8List>{};
    for (final photo in backup.progressPhotos) {
      final expectedName = _photoName(photo.id);
      if (photo.imagePath != expectedName) {
        throw const FormatException('Unsafe progress photo path');
      }
      final photoBytes = archive.find(expectedName)?.readBytes();
      if (photoBytes == null || photoBytes.isEmpty) {
        throw FormatException('Progress photo is missing: ${photo.id}');
      }
      photos[photo.id] = photoBytes;
      final thumbnailBytes =
          archive.find(_thumbnailName(photo.id))?.readBytes();
      if (thumbnailBytes != null) thumbnails[photo.id] = thumbnailBytes;
    }
    return DecodedBackup(
      backup: backup,
      photos: photos,
      thumbnails: thumbnails,
    );
  }

  @visibleForTesting
  static Future<ImportResult> restoreArchive(
    NutritionProvider nutrition,
    List<int> bytes,
  ) async {
    final incoming = decodeArchive(bytes);
    final rollbackBytes = await buildArchive(nutrition.createBackup());

    try {
      await _applyDecoded(nutrition, incoming);
    } catch (error) {
      try {
        await _applyDecoded(nutrition, decodeArchive(rollbackBytes));
      } catch (rollbackError) {
        throw StateError(
          'Import failed and rollback could not be completed: '
          '$error; rollback: $rollbackError',
        );
      }
      rethrow;
    }

    return ImportResult(
      success: true,
      message: 'Backup restored successfully',
      itemsImported: _itemCount(incoming.backup),
    );
  }

  static Future<void> _applyDecoded(
    NutritionProvider nutrition,
    DecodedBackup decoded,
  ) async {
    await nutrition.clearProgressPhotoFilesForRestore();
    final restoredPhotos = <ProgressPhoto>[];
    for (final metadata in decoded.backup.progressPhotos) {
      restoredPhotos.add(
        await nutrition.stageBackupPhoto(
          metadata,
          decoded.photos[metadata.id]!,
          thumbnailBytes: decoded.thumbnails[metadata.id],
        ),
      );
    }
    await nutrition.replaceFromBackup(
      decoded.backup.copyWith(progressPhotos: restoredPhotos),
    );
  }

  static Map<String, dynamic> _encodeManifest(
    NutritionBackup backup,
    List<Map<String, dynamic>> photos,
  ) =>
      {
        'version': archiveVersion,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'goals': backup.goals?.toJson(),
        'profile': backup.profile?.toJson(),
        'foodEntries': backup.foodEntries.map((e) => e.toJson()).toList(),
        'waterEntries': backup.waterEntries.map((e) => e.toJson()).toList(),
        'weightEntries': backup.weightEntries.map((e) => e.toJson()).toList(),
        'workoutEntries': backup.workoutEntries.map((e) => e.toJson()).toList(),
        'recipes': backup.recipes.map((e) => e.toJson()).toList(),
        'plannedMeals': backup.plannedMeals.map((e) => e.toJson()).toList(),
        'customFoods': backup.customFoods.map((e) => e.toJson()).toList(),
        'favoriteFoods': backup.favoriteFoods.map((e) => e.toJson()).toList(),
        'customPortions': backup.customPortions.map((e) => e.toJson()).toList(),
        'recentFoods': backup.recentFoods.map((e) => e.toJson()).toList(),
        'recentFoodMeals': backup.recentFoodMeals,
        'userStats': backup.userStats.toJson(),
        'shoppingListChecked': backup.shoppingListChecked.toList()..sort(),
        'progressPhotos': photos,
      };

  static NutritionBackup _decodeManifest(Map<String, dynamic> json) =>
      NutritionBackup(
        goals: json['goals'] == null
            ? null
            : NutritionGoals.fromJson(json['goals'] as Map<String, dynamic>),
        profile: json['profile'] == null
            ? null
            : UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
        foodEntries: _decodeList(json, 'foodEntries', FoodEntry.fromJson),
        waterEntries: _decodeList(json, 'waterEntries', WaterEntry.fromJson),
        weightEntries: _decodeList(json, 'weightEntries', WeightEntry.fromJson),
        workoutEntries:
            _decodeList(json, 'workoutEntries', WorkoutEntry.fromJson),
        recipes: _decodeList(json, 'recipes', Recipe.fromJson),
        plannedMeals: _decodeList(json, 'plannedMeals', PlannedMeal.fromJson),
        customFoods: _decodeList(json, 'customFoods', FoodItem.fromJson),
        favoriteFoods: _decodeList(json, 'favoriteFoods', FoodItem.fromJson),
        customPortions:
            _decodeList(json, 'customPortions', CustomPortion.fromJson),
        recentFoods: _decodeList(json, 'recentFoods', FoodItem.fromJson),
        recentFoodMeals:
            (json['recentFoodMeals'] as Map<String, dynamic>? ?? const {})
                .map((key, value) => MapEntry(key, value as String)),
        userStats: UserStats.fromJson(
          json['userStats'] as Map<String, dynamic>? ?? const {},
        ),
        shoppingListChecked:
            (json['shoppingListChecked'] as List<dynamic>? ?? const [])
                .cast<String>()
                .toSet(),
        progressPhotos:
            _decodeList(json, 'progressPhotos', ProgressPhoto.fromJson),
      );

  static List<T> _decodeList<T>(
    Map<String, dynamic> json,
    String key,
    T Function(Map<String, dynamic>) decode,
  ) {
    final values = json[key];
    if (values is! List<dynamic>) {
      throw FormatException('Backup field "$key" is missing or invalid');
    }
    return values
        .map((value) => decode(value as Map<String, dynamic>))
        .toList();
  }

  static int _itemCount(NutritionBackup backup) =>
      backup.foodEntries.length +
      backup.waterEntries.length +
      backup.weightEntries.length +
      backup.workoutEntries.length +
      backup.recipes.length +
      backup.plannedMeals.length +
      backup.customFoods.length +
      backup.favoriteFoods.length +
      backup.customPortions.length +
      backup.progressPhotos.length;

  static String _photoName(String id) {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) {
      throw const FormatException('Invalid progress photo identifier');
    }
    return 'photos/$id.jpg';
  }

  static String _thumbnailName(String id) => 'photos/${id}_thumb.jpg';
}

class DecodedBackup {
  final NutritionBackup backup;
  final Map<String, Uint8List> photos;
  final Map<String, Uint8List> thumbnails;

  const DecodedBackup({
    required this.backup,
    required this.photos,
    required this.thumbnails,
  });
}

class ImportResult {
  final bool success;
  final String message;
  final int itemsImported;

  const ImportResult({
    required this.success,
    required this.message,
    this.itemsImported = 0,
  });
}
