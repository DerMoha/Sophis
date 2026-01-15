import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/food_entry.dart';
import '../models/water_entry.dart';
import '../models/weight_entry.dart';
import '../models/recipe.dart';
import '../models/meal_plan.dart';
import '../models/nutrition_goals.dart';
import '../models/user_profile.dart';
import '../models/workout_entry.dart';
import 'nutrition_provider.dart';

/// Service for exporting and importing all app data as JSON
class DataExportService {
  static const String _exportVersion = '1.0';

  /// Export all app data to a shareable JSON file
  static Future<bool> exportData(NutritionProvider nutrition) async {
    try {
      // Gather all data
      final exportData = {
        'version': _exportVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'goals': nutrition.goals?.toJson(),
        'profile': nutrition.profile?.toJson(),
        'foodEntries': nutrition.entries.map((e) => e.toJson()).toList(),
        'waterEntries': nutrition.waterEntries.map((e) => e.toJson()).toList(),
        'weightEntries': nutrition.weightEntries.map((e) => e.toJson()).toList(),
        'recipes': nutrition.recipes.map((e) => e.toJson()).toList(),
        'plannedMeals': nutrition.plannedMeals.map((e) => e.toJson()).toList(),
        'workoutEntries': nutrition.workoutEntries.map((e) => e.toJson()).toList(),
      };

      // Convert to formatted JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // Create temp file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = 'sophis_backup_$timestamp.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Sophis Data Backup',
      );

      return true;
    } catch (e) {
      debugPrint('Export failed: $e');
      return false;
    }
  }

  /// Import data from a JSON file, replacing all current data
  static Future<ImportResult> importData(NutritionProvider nutrition) async {
    try {
      // Pick a JSON file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult(success: false, message: 'No file selected');
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate version
      final version = data['version'] as String?;
      if (version == null) {
        return ImportResult(success: false, message: 'Invalid backup file format');
      }

      // Clear existing data before import
      await nutrition.clearAllData();

      // Import data
      int itemsImported = 0;

      // Goals
      if (data['goals'] != null) {
        final goals = NutritionGoals.fromJson(data['goals'] as Map<String, dynamic>);
        await nutrition.setGoals(goals);
        itemsImported++;
      }

      // Profile
      if (data['profile'] != null) {
        final profile = UserProfile.fromJson(data['profile'] as Map<String, dynamic>);
        await nutrition.setProfile(profile);
        itemsImported++;
      }

      // Food entries
      if (data['foodEntries'] != null) {
        final entries = (data['foodEntries'] as List)
            .map((e) => FoodEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        for (final entry in entries) {
           await nutrition.addFoodEntry(entry);
        }
        itemsImported += entries.length;
      }

      // Water entries
      if (data['waterEntries'] != null) {
        final entries = (data['waterEntries'] as List)
            .map((e) => WaterEntry.fromJson(e as Map<String, dynamic>))
            .toList();
         for (final entry in entries) {
           await nutrition.restoreWaterEntry(entry);
         }
         itemsImported += entries.length;
      }

      // Weight entries
      if (data['weightEntries'] != null) {
        final entries = (data['weightEntries'] as List)
            .map((e) => WeightEntry.fromJson(e as Map<String, dynamic>))
            .toList();
         for (final entry in entries) {
            await nutrition.restoreWeightEntry(entry);
         }
         itemsImported += entries.length;
      }

      // Recipes
      if (data['recipes'] != null) {
        final recipes = (data['recipes'] as List)
            .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
            .toList();
        for (final recipe in recipes) {
           await nutrition.addRecipe(recipe);
        }
        itemsImported += recipes.length;
      }

      // Planned meals
      if (data['plannedMeals'] != null) {
        final meals = (data['plannedMeals'] as List)
            .map((e) => PlannedMeal.fromJson(e as Map<String, dynamic>))
            .toList();
        for (final meal in meals) {
           await nutrition.addPlannedMeal(meal);
        }
        itemsImported += meals.length;
      }

      // Workout entries
      if (data['workoutEntries'] != null) {
        final entries = (data['workoutEntries'] as List)
            .map((e) => WorkoutEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        for (final entry in entries) {
           await nutrition.restoreWorkoutEntry(entry);
        }
        itemsImported += entries.length;
      }

      return ImportResult(
        success: true,
        message: 'Imported $itemsImported items',
        itemsImported: itemsImported,
      );
    } catch (e) {
      debugPrint('Import failed: $e');
      return ImportResult(success: false, message: 'Import failed: $e');
    }
  }
}

class ImportResult {
  final bool success;
  final String message;
  final int itemsImported;

  ImportResult({
    required this.success,
    required this.message,
    this.itemsImported = 0,
  });
}
