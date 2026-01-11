import 'package:flutter/material.dart';
import 'custom_meal_type.dart';

enum AIMode { offlineBasic, offlinePro, cloud }

enum UnitSystem { metric, imperial }

/// Dashboard card configuration
class DashboardCard {
  final String id;
  final bool visible;

  const DashboardCard({required this.id, this.visible = true});

  Map<String, dynamic> toJson() => {'id': id, 'visible': visible};

  factory DashboardCard.fromJson(Map<String, dynamic> json) => DashboardCard(
    id: json['id'] as String,
    visible: json['visible'] as bool? ?? true,
  );

  DashboardCard copyWith({bool? visible}) => DashboardCard(
    id: id,
    visible: visible ?? this.visible,
  );
}

/// Dashboard card IDs and default order
class DashboardCardIds {
  static const foodDiary = 'food_diary';
  static const mealPlanner = 'meal_planner';
  static const weight = 'weight';
  static const recipes = 'recipes';
  static const activity = 'activity';
  static const workout = 'workout';

  static const List<String> defaultOrder = [
    foodDiary,
    mealPlanner,
    weight,
    recipes,
    activity,
    workout,
  ];

  static List<DashboardCard> get defaultCards =>
      defaultOrder.map((id) => DashboardCard(id: id)).toList();
}

/// Preset accent colors
class AccentColors {
  static const List<Color> presets = [
    Color(0xFF3B82F6), // Blue (default)
    Color(0xFF8B5CF6), // Purple
    Color(0xFF10B981), // Green
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFF6366F1), // Indigo
  ];
  
  static const int defaultColorValue = 0xFF3B82F6;
}

/// App settings and preferences
class AppSettings {
  final AIMode aiMode;
  final ThemeMode themeMode;
  final String? localeOverride;
  final double waterGoalMl;
  final int accentColorValue;
  final String? breakfastReminderTime; // "HH:mm" format or null
  final String? lunchReminderTime;
  final String? dinnerReminderTime;
  final bool remindersEnabled;
  final bool healthSyncEnabled;
  // Custom water quick-add sizes (ml)
  final int waterSize1;
  final int waterSize2;
  final int waterSize3;
  final int waterSize4;
  // Unit system preference
  final UnitSystem unitSystem;
  // Dashboard card configuration
  final List<DashboardCard> dashboardCards;
  // Custom meal types
  final List<CustomMealType> customMealTypes;

  const AppSettings({
    this.aiMode = AIMode.offlineBasic,
    this.themeMode = ThemeMode.system,
    this.localeOverride,
    this.waterGoalMl = 2000,
    this.accentColorValue = AccentColors.defaultColorValue,
    this.breakfastReminderTime,
    this.lunchReminderTime,
    this.dinnerReminderTime,
    this.remindersEnabled = false,
    this.healthSyncEnabled = false,
    this.waterSize1 = 150,
    this.waterSize2 = 250,
    this.waterSize3 = 500,
    this.waterSize4 = 1000,
    this.unitSystem = UnitSystem.metric,
    this.dashboardCards = const [],
    this.customMealTypes = const [],
  });

  Color get accentColor => Color(accentColorValue);

  Map<String, dynamic> toJson() => {
    'aiMode': aiMode.index,
    'themeMode': themeMode.index,
    'localeOverride': localeOverride,
    'waterGoalMl': waterGoalMl,
    'accentColorValue': accentColorValue,
    'breakfastReminderTime': breakfastReminderTime,
    'lunchReminderTime': lunchReminderTime,
    'dinnerReminderTime': dinnerReminderTime,
    'remindersEnabled': remindersEnabled,
    'healthSyncEnabled': healthSyncEnabled,
    'waterSize1': waterSize1,
    'waterSize2': waterSize2,
    'waterSize3': waterSize3,
    'waterSize4': waterSize4,
    'unitSystem': unitSystem.index,
    'dashboardCards': dashboardCards.map((c) => c.toJson()).toList(),
    'customMealTypes': customMealTypes.map((m) => m.toJson()).toList(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    aiMode: json['aiMode'] != null 
        ? AIMode.values[json['aiMode']] 
        : AIMode.offlineBasic,
    themeMode: json['themeMode'] != null 
        ? ThemeMode.values[json['themeMode']] 
        : ThemeMode.system,
    localeOverride: json['localeOverride'],
    waterGoalMl: (json['waterGoalMl'] as num?)?.toDouble() ?? 2000,
    accentColorValue: json['accentColorValue'] ?? AccentColors.defaultColorValue,
    breakfastReminderTime: json['breakfastReminderTime'],
    lunchReminderTime: json['lunchReminderTime'],
    dinnerReminderTime: json['dinnerReminderTime'],
    remindersEnabled: json['remindersEnabled'] ?? false,
    healthSyncEnabled: json['healthSyncEnabled'] ?? false,
    waterSize1: json['waterSize1'] ?? 150,
    waterSize2: json['waterSize2'] ?? 250,
    waterSize3: json['waterSize3'] ?? 500,
    waterSize4: json['waterSize4'] ?? 1000,
    unitSystem: json['unitSystem'] != null
        ? UnitSystem.values[json['unitSystem']]
        : UnitSystem.metric,
    dashboardCards: (json['dashboardCards'] as List<dynamic>?)
        ?.map((c) => DashboardCard.fromJson(c as Map<String, dynamic>))
        .toList() ?? const [],
    customMealTypes: (json['customMealTypes'] as List<dynamic>?)
        ?.map((m) => CustomMealType.fromJson(m as Map<String, dynamic>))
        .toList() ?? const [],
  );

  AppSettings copyWith({
    AIMode? aiMode,
    ThemeMode? themeMode,
    String? localeOverride,
    double? waterGoalMl,
    int? accentColorValue,
    String? breakfastReminderTime,
    String? lunchReminderTime,
    String? dinnerReminderTime,
    bool? remindersEnabled,
    bool? healthSyncEnabled,
    int? waterSize1,
    int? waterSize2,
    int? waterSize3,
    int? waterSize4,
    UnitSystem? unitSystem,
    List<DashboardCard>? dashboardCards,
    List<CustomMealType>? customMealTypes,
    bool clearLocale = false,
    bool clearBreakfast = false,
    bool clearLunch = false,
    bool clearDinner = false,
  }) => AppSettings(
    aiMode: aiMode ?? this.aiMode,
    themeMode: themeMode ?? this.themeMode,
    localeOverride: clearLocale ? null : (localeOverride ?? this.localeOverride),
    waterGoalMl: waterGoalMl ?? this.waterGoalMl,
    accentColorValue: accentColorValue ?? this.accentColorValue,
    breakfastReminderTime: clearBreakfast ? null : (breakfastReminderTime ?? this.breakfastReminderTime),
    lunchReminderTime: clearLunch ? null : (lunchReminderTime ?? this.lunchReminderTime),
    dinnerReminderTime: clearDinner ? null : (dinnerReminderTime ?? this.dinnerReminderTime),
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    healthSyncEnabled: healthSyncEnabled ?? this.healthSyncEnabled,
    waterSize1: waterSize1 ?? this.waterSize1,
    waterSize2: waterSize2 ?? this.waterSize2,
    waterSize3: waterSize3 ?? this.waterSize3,
    waterSize4: waterSize4 ?? this.waterSize4,
    unitSystem: unitSystem ?? this.unitSystem,
    dashboardCards: dashboardCards ?? this.dashboardCards,
    customMealTypes: customMealTypes ?? this.customMealTypes,
  );
}

