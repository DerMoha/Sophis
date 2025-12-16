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

  SettingsProvider(this._storage) : _settings = _storage.loadSettings() {
    // Schedule notifications on startup based on saved settings
    _updateNotifications();
  }

  AppSettings get settings => _settings;
  ThemeMode get themeMode => _settings.themeMode;
  String? get localeOverride => _settings.localeOverride;
  AIMode get aiMode => _settings.aiMode;
  String? get geminiApiKey => _settings.geminiApiKey;
  bool get hasGeminiApiKey => _settings.hasGeminiApiKey;
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
    _settings = _settings.copyWith(
      geminiApiKey: key,
      clearApiKey: key == null || key.isEmpty,
    );
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> setWaterGoal(double ml) async {
    _settings = _settings.copyWith(waterGoalMl: ml);
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
}
