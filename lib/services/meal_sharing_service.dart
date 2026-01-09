import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/food_entry.dart';
import '../models/shareable_meal.dart';

/// Service for sharing and receiving meals between users
class MealSharingService {
  /// Create a shareable meal from food entries
  static ShareableMeal createShareableMeal(
    List<FoodEntry> entries, {
    String? title,
  }) {
    if (entries.isEmpty) {
      throw ArgumentError('Cannot share an empty meal');
    }
    return ShareableMeal.fromFoodEntries(entries, title: title);
  }

  /// Generate a deep link for sharing
  static String generateDeepLink(ShareableMeal meal) {
    return meal.toDeepLink();
  }

  /// Parse a deep link URL and return the meal data
  /// Returns null if the URL is invalid or not a share link
  static ShareableMeal? parseDeepLink(String url) {
    return ShareableMeal.fromDeepLink(url);
  }

  /// Check if a URL is a valid Sophis share link
  static bool isShareLink(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.scheme == ShareableMeal.urlScheme &&
          uri.host == ShareableMeal.urlHost;
    } catch (e) {
      return false;
    }
  }

  /// Share the meal using the system share sheet
  static Future<void> shareViaSystem(ShareableMeal meal) async {
    final link = meal.toDeepLink();
    final itemCount = meal.items.length;
    final totalCal = meal.totalCalories.round();

    String text;
    if (meal.title != null) {
      text = '${meal.title} ($itemCount ${itemCount == 1 ? 'item' : 'items'}, $totalCal kcal)\n\n$link';
    } else {
      text = 'Shared meal ($itemCount ${itemCount == 1 ? 'item' : 'items'}, $totalCal kcal)\n\n$link';
    }

    await Share.share(text, subject: meal.title ?? 'Shared Meal');
  }

  /// Copy the deep link to clipboard
  static Future<void> copyToClipboard(ShareableMeal meal) async {
    final link = meal.toDeepLink();
    await Clipboard.setData(ClipboardData(text: link));
  }

  /// Validate incoming share data
  static ShareableMealValidation validateMeal(ShareableMeal? meal) {
    if (meal == null) {
      return ShareableMealValidation(
        isValid: false,
        error: 'Invalid share data',
      );
    }

    if (meal.items.isEmpty) {
      return ShareableMealValidation(
        isValid: false,
        error: 'Shared meal contains no items',
      );
    }

    // Check for reasonable values
    for (final item in meal.items) {
      if (item.calories < 0 || item.calories > 10000) {
        return ShareableMealValidation(
          isValid: false,
          error: 'Invalid calorie value for ${item.name}',
        );
      }
      if (item.protein < 0 ||
          item.carbs < 0 ||
          item.fat < 0 ||
          item.protein > 1000 ||
          item.carbs > 1000 ||
          item.fat > 1000) {
        return ShareableMealValidation(
          isValid: false,
          error: 'Invalid macro values for ${item.name}',
        );
      }
    }

    return ShareableMealValidation(isValid: true, meal: meal);
  }
}

/// Result of meal validation
class ShareableMealValidation {
  final bool isValid;
  final String? error;
  final ShareableMeal? meal;

  const ShareableMealValidation({
    required this.isValid,
    this.error,
    this.meal,
  });
}
