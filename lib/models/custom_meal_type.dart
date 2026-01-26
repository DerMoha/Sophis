import 'package:flutter/material.dart';

/// Custom meal type with user-defined properties
class CustomMealType {
  final String id;
  final String name;
  final int iconCodePoint;
  final int colorValue;
  final String? reminderTime; // "HH:mm" format or null
  final int sortOrder;
  final bool isDefault; // Default meals cannot be deleted

  const CustomMealType({
    required this.id,
    required this.name,
    this.iconCodePoint = 0xe532, // Icons.restaurant default
    this.colorValue = 0xFF3B82F6,
    this.reminderTime,
    this.sortOrder = 0,
    this.isDefault = false,
  });

  IconData get icon {
    return availableIcons.firstWhere(
      (icon) => icon.codePoint == iconCodePoint,
      orElse: () => Icons.restaurant,
    );
  }

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconCodePoint': iconCodePoint,
        'colorValue': colorValue,
        'reminderTime': reminderTime,
        'sortOrder': sortOrder,
        'isDefault': isDefault,
      };

  factory CustomMealType.fromJson(Map<String, dynamic> json) => CustomMealType(
        id: json['id'] as String,
        name: json['name'] as String,
        iconCodePoint:
            json['iconCodePoint'] as int? ?? Icons.restaurant.codePoint,
        colorValue: json['colorValue'] as int? ?? 0xFF3B82F6,
        reminderTime: json['reminderTime'] as String?,
        sortOrder: json['sortOrder'] as int? ?? 0,
        isDefault: json['isDefault'] as bool? ?? false,
      );

  CustomMealType copyWith({
    String? name,
    int? iconCodePoint,
    int? colorValue,
    String? reminderTime,
    int? sortOrder,
    bool clearReminder = false,
  }) =>
      CustomMealType(
        id: id,
        name: name ?? this.name,
        iconCodePoint: iconCodePoint ?? this.iconCodePoint,
        colorValue: colorValue ?? this.colorValue,
        reminderTime:
            clearReminder ? null : (reminderTime ?? this.reminderTime),
        sortOrder: sortOrder ?? this.sortOrder,
        isDefault: isDefault,
      );

  /// Default meal types matching existing meal IDs for backward compatibility
  static List<CustomMealType> get defaults => [
        CustomMealType(
          id: 'breakfast',
          name: 'Breakfast',
          iconCodePoint: Icons.wb_twilight_rounded.codePoint,
          colorValue: 0xFFF59E0B, // Amber
          sortOrder: 0,
          isDefault: true,
        ),
        CustomMealType(
          id: 'lunch',
          name: 'Lunch',
          iconCodePoint: Icons.wb_sunny_rounded.codePoint,
          colorValue: 0xFF3B82F6, // Blue
          sortOrder: 1,
          isDefault: true,
        ),
        CustomMealType(
          id: 'dinner',
          name: 'Dinner',
          iconCodePoint: Icons.nights_stay_rounded.codePoint,
          colorValue: 0xFF8B5CF6, // Purple
          sortOrder: 2,
          isDefault: true,
        ),
        CustomMealType(
          id: 'snack',
          name: 'Snacks',
          iconCodePoint: Icons.cookie_outlined.codePoint,
          colorValue: 0xFF10B981, // Green
          sortOrder: 3,
          isDefault: true,
        ),
      ];

  /// Available icons for meal types
  static List<IconData> get availableIcons => [
        Icons.wb_twilight_rounded,
        Icons.wb_sunny_rounded,
        Icons.nights_stay_rounded,
        Icons.cookie_outlined,
        Icons.restaurant_outlined,
        Icons.lunch_dining_outlined,
        Icons.dinner_dining_outlined,
        Icons.breakfast_dining_outlined,
        Icons.local_cafe_outlined,
        Icons.local_pizza_outlined,
        Icons.icecream_outlined,
        Icons.cake_outlined,
        Icons.fastfood_outlined,
        Icons.ramen_dining_outlined,
        Icons.bakery_dining_outlined,
        Icons.egg_outlined,
        Icons.sports_bar_outlined,
        Icons.local_bar_outlined,
        Icons.emoji_food_beverage_outlined,
        Icons.rice_bowl_outlined,
      ];

  /// Available colors for meal types
  static List<Color> get availableColors => const [
        Color(0xFFF59E0B), // Amber
        Color(0xFF3B82F6), // Blue
        Color(0xFF8B5CF6), // Purple
        Color(0xFF10B981), // Green
        Color(0xFFEF4444), // Red
        Color(0xFFEC4899), // Pink
        Color(0xFF06B6D4), // Cyan
        Color(0xFF6366F1), // Indigo
        Color(0xFFF97316), // Orange
        Color(0xFF14B8A6), // Teal
        Color(0xFFA855F7), // Violet
        Color(0xFF64748B), // Slate
      ];
}
