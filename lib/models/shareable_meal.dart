import 'dart:convert';
import 'dart:io';

import 'food_entry.dart';
import '../services/gemini_food_service.dart';

/// A food item that can be shared between users
class SharedFoodItem {
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double? portionGrams;

  const SharedFoodItem({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.portionGrams,
  });

  /// Compact JSON for URL encoding
  Map<String, dynamic> toJson() => {
        'n': name,
        'c': calories,
        'p': protein,
        'cb': carbs,
        'f': fat,
        if (portionGrams != null) 'g': portionGrams,
      };

  factory SharedFoodItem.fromJson(Map<String, dynamic> json) => SharedFoodItem(
        name: json['n'] as String,
        calories: (json['c'] as num).toDouble(),
        protein: (json['p'] as num).toDouble(),
        carbs: (json['cb'] as num).toDouble(),
        fat: (json['f'] as num).toDouble(),
        portionGrams: json['g'] != null ? (json['g'] as num).toDouble() : null,
      );

  /// Create from a FoodEntry
  factory SharedFoodItem.fromFoodEntry(FoodEntry entry) => SharedFoodItem(
        name: entry.name,
        calories: entry.calories,
        protein: entry.protein,
        carbs: entry.carbs,
        fat: entry.fat,
      );

  /// Create from a FoodAnalysis (AI result)
  factory SharedFoodItem.fromFoodAnalysis(FoodAnalysis analysis, {String? customName}) =>
      SharedFoodItem(
        name: customName ?? '${analysis.name} (${analysis.portionDisplay})',
        calories: analysis.calories,
        protein: analysis.protein,
        carbs: analysis.carbs,
        fat: analysis.fat,
        portionGrams: analysis.portionGrams,
      );

  /// Convert to a FoodEntry for logging
  FoodEntry toFoodEntry(String meal) => FoodEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        timestamp: DateTime.now(),
        meal: meal,
      );
}

/// A shareable meal containing one or more food items
class ShareableMeal {
  static const String version = '1';
  static const String urlScheme = 'sophis';
  static const String urlHost = 'share';

  final String v;
  final String? title;
  final List<SharedFoodItem> items;

  const ShareableMeal({
    this.v = version,
    this.title,
    required this.items,
  });

  // Computed totals
  double get totalCalories => items.fold(0, (sum, i) => sum + i.calories);
  double get totalProtein => items.fold(0, (sum, i) => sum + i.protein);
  double get totalCarbs => items.fold(0, (sum, i) => sum + i.carbs);
  double get totalFat => items.fold(0, (sum, i) => sum + i.fat);

  Map<String, dynamic> toJson() => {
        'v': v,
        if (title != null) 't': title,
        'i': items.map((i) => i.toJson()).toList(),
      };

  factory ShareableMeal.fromJson(Map<String, dynamic> json) {
    final itemsList = json['i'] as List;
    return ShareableMeal(
      v: json['v'] as String? ?? version,
      title: json['t'] as String?,
      items: itemsList
          .map((i) => SharedFoodItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Create from a list of FoodEntries
  factory ShareableMeal.fromFoodEntries(List<FoodEntry> entries,
      {String? title}) {
    return ShareableMeal(
      title: title,
      items: entries.map((e) => SharedFoodItem.fromFoodEntry(e)).toList(),
    );
  }

  /// Encode to a compact string for URL/QR code
  /// Uses GZIP compression for payloads > 500 bytes
  String toEncodedString() {
    final jsonStr = jsonEncode(toJson());
    final bytes = utf8.encode(jsonStr);

    // Use GZIP for larger payloads
    if (bytes.length > 500) {
      final compressed = gzip.encode(bytes);
      return '${base64Url.encode(compressed)}|z';
    }

    return base64Url.encode(bytes);
  }

  /// Decode from an encoded string
  factory ShareableMeal.fromEncodedString(String encoded) {
    List<int> bytes;

    // Check if compressed
    if (encoded.endsWith('|z')) {
      final base64Data = encoded.substring(0, encoded.length - 2);
      final compressed = base64Url.decode(base64Data);
      bytes = gzip.decode(compressed);
    } else {
      bytes = base64Url.decode(encoded);
    }

    final jsonStr = utf8.decode(bytes);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return ShareableMeal.fromJson(json);
  }

  /// Generate full deep link URL
  String toDeepLink() {
    final encoded = toEncodedString();
    return '$urlScheme://$urlHost?d=$encoded';
  }

  /// Parse a deep link URL and extract the meal data
  static ShareableMeal? fromDeepLink(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme != urlScheme || uri.host != urlHost) {
        return null;
      }

      final data = uri.queryParameters['d'];
      if (data == null || data.isEmpty) {
        return null;
      }

      return ShareableMeal.fromEncodedString(data);
    } catch (e) {
      return null;
    }
  }

  /// Convert all items to FoodEntries for the given meal
  List<FoodEntry> toFoodEntries(String meal) {
    return items.map((item) => item.toFoodEntry(meal)).toList();
  }
}
