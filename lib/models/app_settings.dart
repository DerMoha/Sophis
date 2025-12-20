import 'package:flutter/material.dart';

enum AIMode { offlineBasic, offlinePro, cloud }

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
  );
}

