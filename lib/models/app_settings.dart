import 'package:flutter/material.dart';

enum AIMode { offlineBasic, offlinePro, cloud }

/// App settings and preferences
class AppSettings {
  final String? geminiApiKey;
  final AIMode aiMode;
  final ThemeMode themeMode;
  final String? localeOverride; // null = system, 'en', 'de'
  final double waterGoalMl;

  const AppSettings({
    this.geminiApiKey,
    this.aiMode = AIMode.offlineBasic,
    this.themeMode = ThemeMode.system,
    this.localeOverride,
    this.waterGoalMl = 2000,
  });

  bool get hasGeminiApiKey => geminiApiKey != null && geminiApiKey!.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'geminiApiKey': geminiApiKey,
    'aiMode': aiMode.index,
    'themeMode': themeMode.index,
    'localeOverride': localeOverride,
    'waterGoalMl': waterGoalMl,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    geminiApiKey: json['geminiApiKey'],
    aiMode: json['aiMode'] != null 
        ? AIMode.values[json['aiMode']] 
        : AIMode.offlineBasic,
    themeMode: json['themeMode'] != null 
        ? ThemeMode.values[json['themeMode']] 
        : ThemeMode.system,
    localeOverride: json['localeOverride'],
    waterGoalMl: (json['waterGoalMl'] as num?)?.toDouble() ?? 2000,
  );

  AppSettings copyWith({
    String? geminiApiKey,
    AIMode? aiMode,
    ThemeMode? themeMode,
    String? localeOverride,
    double? waterGoalMl,
    bool clearApiKey = false,
    bool clearLocale = false,
  }) => AppSettings(
    geminiApiKey: clearApiKey ? null : (geminiApiKey ?? this.geminiApiKey),
    aiMode: aiMode ?? this.aiMode,
    themeMode: themeMode ?? this.themeMode,
    localeOverride: clearLocale ? null : (localeOverride ?? this.localeOverride),
    waterGoalMl: waterGoalMl ?? this.waterGoalMl,
  );
}
