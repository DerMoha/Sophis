import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import 'storage_service.dart';
import 'notification_service.dart';
import 'health_service.dart';

/// Settings provider for theme, locale, and AI mode
class SettingsProvider extends ChangeNotifier {
  final StorageService _storage;
  final NotificationService _notifications = NotificationService();
  AppSettings _settings;
  String? _geminiApiKey;

  SettingsProvider(this._storage) : _settings = _storage.loadSettings() {
    _loadSecureData();
    // Schedule notifications on startup based on saved settings
    _updateNotifications();
  }

  Future<void> _loadSecureData() async {
    _geminiApiKey = await _storage.loadApiKey();
    notifyListeners();
  }

  AppSettings get settings => _settings;
  ThemeMode get themeMode => _settings.themeMode;
  String? get localeOverride => _settings.localeOverride;
  AIMode get aiMode => _settings.aiMode;

  String? get geminiApiKey => _geminiApiKey;
  bool get hasGeminiApiKey => _geminiApiKey != null && _geminiApiKey!.isNotEmpty;
  double get waterGoalMl => _settings.waterGoalMl;
  
  // Accent color
  Color get accentColor => _settings.accentColor;
  int get accentColorValue => _settings.accentColorValue;
  
  // Meal reminders
  bool get remindersEnabled => _settings.remindersEnabled;
  String? get breakfastReminderTime => _settings.breakfastReminderTime;
  String? get lunchReminderTime => _settings.lunchReminderTime;
  String? get dinnerReminderTime => _settings.dinnerReminderTime;
  
  // Health sync
  bool get healthSyncEnabled => _settings.healthSyncEnabled;

  // Unit system
  UnitSystem get unitSystem => _settings.unitSystem;
  bool get isImperial => _settings.unitSystem == UnitSystem.imperial;

  Locale? get locale {
    if (_settings.localeOverride == null) return null;
    return Locale(_settings.localeOverride!);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> setLocale(String? localeCode) async {
    _settings = _settings.copyWith(
      localeOverride: localeCode,
      clearLocale: localeCode == null,
    );
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> setAIMode(AIMode mode) async {
    _settings = _settings.copyWith(aiMode: mode);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> setGeminiApiKey(String? key) async {
    _geminiApiKey = key;
    await _storage.saveApiKey(key);
    notifyListeners();
  }

  Future<void> setWaterGoal(double ml) async {
    _settings = _settings.copyWith(waterGoalMl: ml);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> setUnitSystem(UnitSystem system) async {
    _settings = _settings.copyWith(unitSystem: system);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> setAccentColor(int colorValue) async {
    _settings = _settings.copyWith(accentColorValue: colorValue);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    if (enabled) {
      // Request permission when user enables reminders
      final granted = await _notifications.requestPermissions();
      if (!granted) {
        // Permission denied, don't enable reminders
        return;
      }
    }
    
    _settings = _settings.copyWith(remindersEnabled: enabled);
    await _storage.saveSettings(_settings);
    await _updateNotifications();
    notifyListeners();
  }

  Future<void> setBreakfastReminder(String? time) async {
    _settings = _settings.copyWith(
      breakfastReminderTime: time,
      clearBreakfast: time == null,
    );
    await _storage.saveSettings(_settings);
    await _updateNotifications();
    notifyListeners();
  }

  Future<void> setLunchReminder(String? time) async {
    _settings = _settings.copyWith(
      lunchReminderTime: time,
      clearLunch: time == null,
    );
    await _storage.saveSettings(_settings);
    await _updateNotifications();
    notifyListeners();
  }

  Future<void> setDinnerReminder(String? time) async {
    _settings = _settings.copyWith(
      dinnerReminderTime: time,
      clearDinner: time == null,
    );
    await _storage.saveSettings(_settings);
    await _updateNotifications();
    notifyListeners();
  }

  /// Update scheduled notifications based on current settings
  Future<void> _updateNotifications() async {
    await _notifications.updateMealReminders(
      enabled: _settings.remindersEnabled,
      breakfastTime: _settings.breakfastReminderTime,
      lunchTime: _settings.lunchReminderTime,
      dinnerTime: _settings.dinnerReminderTime,
    );
  }

  /// Enable or disable health sync
  Future<bool> setHealthSyncEnabled(bool enabled) async {
    if (enabled) {
      // Request permissions when enabling
      final healthService = HealthService();
      final granted = await healthService.requestPermissions();
      if (!granted) {
        // Permission denied, don't enable health sync
        return false;
      }
    }
    
    _settings = _settings.copyWith(healthSyncEnabled: enabled);
    await _storage.saveSettings(_settings);
    notifyListeners();
    return true;
  }

  // Water quick-add sizes
  List<int> get waterSizes => [
    _settings.waterSize1,
    _settings.waterSize2,
    _settings.waterSize3,
    _settings.waterSize4,
  ];

  Future<void> setWaterSizes(int size1, int size2, int size3, int size4) async {
    _settings = _settings.copyWith(
      waterSize1: size1,
      waterSize2: size2,
      waterSize3: size3,
      waterSize4: size4,
    );
    await _storage.saveSettings(_settings);
    notifyListeners();
  }
}
