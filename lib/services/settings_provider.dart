import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import 'storage_service.dart';

/// Settings provider for theme, locale, and AI mode
class SettingsProvider extends ChangeNotifier {
  final StorageService _storage;
  AppSettings _settings;

  SettingsProvider(this._storage) : _settings = _storage.loadSettings();

  AppSettings get settings => _settings;
  ThemeMode get themeMode => _settings.themeMode;
  String? get localeOverride => _settings.localeOverride;
  AIMode get aiMode => _settings.aiMode;
  String? get geminiApiKey => _settings.geminiApiKey;
  bool get hasGeminiApiKey => _settings.hasGeminiApiKey;
  double get waterGoalMl => _settings.waterGoalMl;

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
}
