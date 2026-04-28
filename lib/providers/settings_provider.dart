import 'package:flutter/material.dart';

import 'package:sophis/models/app_settings.dart';
import 'package:sophis/models/custom_meal_type.dart';
import 'package:sophis/utils/time_utils.dart';
import 'package:sophis/services/storage_service.dart';
import 'package:sophis/services/notification_service.dart';
import 'package:sophis/services/health_service.dart';

/// Settings provider for theme, locale, and AI mode
class SettingsProvider extends ChangeNotifier {
  final StorageService _storage;
  final NotificationService _notifications = NotificationService();
  AppSettings _settings;
  String? _geminiApiKey;
  String? _offUserId;
  String? _offPassword;

  SettingsProvider(this._storage) : _settings = _storage.loadSettings() {
    _loadSecureData();
    // Schedule notifications on startup based on saved settings
    _updateNotifications();
  }

  Future<void> _loadSecureData() async {
    try {
      _geminiApiKey = await _storage.loadApiKey();
      _offUserId = await _storage.loadOffUserId();
      _offPassword = await _storage.loadOffPassword();
    } catch (e) {
      _geminiApiKey = null;
      _offUserId = null;
      _offPassword = null;
    }
    notifyListeners();
  }

  AppSettings get settings => _settings;
  ThemeMode get themeMode => _settings.themeMode;
  String? get localeOverride => _settings.localeOverride;
  AIMode get aiMode => _settings.aiMode;

  String? get geminiApiKey => _geminiApiKey;
  bool get hasGeminiApiKey =>
      _geminiApiKey != null && _geminiApiKey!.isNotEmpty;

  String? get offUserId => _offUserId;
  String? get offPassword => _offPassword;
  bool get hasOffCredentials =>
      _offUserId != null &&
      _offUserId!.isNotEmpty &&
      _offPassword != null &&
      _offPassword!.isNotEmpty;
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
  bool get healthWeightSyncEnabled => _settings.healthWeightSyncEnabled;
  bool get healthNutritionSyncEnabled => _settings.healthNutritionSyncEnabled;

  // Unit system
  UnitSystem get unitSystem => _settings.unitSystem;
  bool get isImperial => _settings.unitSystem == UnitSystem.imperial;

  Locale? get locale {
    if (_settings.localeOverride == null) return null;
    return Locale(_settings.localeOverride!);
  }

  Future<void> _persistSettings({
    required AppSettings settings,
    bool updateNotifications = false,
  }) async {
    _settings = settings;
    await _storage.saveSettings(_settings);
    if (updateNotifications) {
      await _updateNotifications();
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _persistSettings(settings: _settings.copyWith(themeMode: mode));
  }

  Future<void> setLocale(String? localeCode) async {
    await _persistSettings(
      settings: _settings.copyWith(
        localeOverride: localeCode,
        clearLocale: localeCode == null,
      ),
    );
  }

  Future<void> setAIMode(AIMode mode) async {
    await _persistSettings(settings: _settings.copyWith(aiMode: mode));
  }

  Future<void> setGeminiApiKey(String? key) async {
    _geminiApiKey = key;
    await _storage.saveApiKey(key);
    notifyListeners();
  }

  Future<void> setOffCredentials(String? userId, String? password) async {
    _offUserId = userId;
    _offPassword = password;
    await _storage.saveOffCredentials(userId, password);
    notifyListeners();
  }

  Future<void> setWaterGoal(double ml) async {
    await _persistSettings(settings: _settings.copyWith(waterGoalMl: ml));
  }

  Future<void> setUnitSystem(UnitSystem system) async {
    await _persistSettings(settings: _settings.copyWith(unitSystem: system));
  }

  Future<void> setAccentColor(int colorValue) async {
    await _persistSettings(
      settings: _settings.copyWith(accentColorValue: colorValue),
    );
  }

  bool get showMealMacros => _settings.showMealMacros;
  bool get showSupplements => _settings.showSupplements;

  Future<void> setShowMealMacros(bool enabled) async {
    await _persistSettings(
      settings: _settings.copyWith(showMealMacros: enabled),
    );
  }

  Future<void> setShowSupplements(bool enabled) async {
    await _persistSettings(
      settings: _settings.copyWith(showSupplements: enabled),
    );
  }

  QuickActionSize get quickActionSize => _settings.quickActionSize;

  Future<void> setQuickActionSize(QuickActionSize size) async {
    await _persistSettings(
      settings: _settings.copyWith(quickActionSize: size),
    );
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

    await _persistSettings(
      settings: _settings.copyWith(remindersEnabled: enabled),
      updateNotifications: true,
    );
  }

  Future<void> _setMealReminder({
    required String? time,
    required AppSettings Function(AppSettings settings) buildSettings,
  }) async {
    await _persistSettings(
      settings: buildSettings(_settings),
      updateNotifications: true,
    );
  }

  Future<void> setBreakfastReminder(String? time) {
    return _setMealReminder(
      time: time,
      buildSettings: (settings) => settings.copyWith(
        breakfastReminderTime: time,
        clearBreakfast: time == null,
      ),
    );
  }

  Future<void> setLunchReminder(String? time) async {
    await _setMealReminder(
      time: time,
      buildSettings: (settings) => settings.copyWith(
        lunchReminderTime: time,
        clearLunch: time == null,
      ),
    );
  }

  Future<void> setDinnerReminder(String? time) async {
    await _setMealReminder(
      time: time,
      buildSettings: (settings) => settings.copyWith(
        dinnerReminderTime: time,
        clearDinner: time == null,
      ),
    );
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

    await _persistSettings(
      settings: _settings.copyWith(healthSyncEnabled: enabled),
    );
    return true;
  }

  Future<bool> setHealthWeightSyncEnabled(bool enabled) async {
    if (enabled) {
      final healthService = HealthService();
      final granted = await healthService.requestWeightPermissions();
      if (!granted) return false;
    }

    await _persistSettings(
      settings: _settings.copyWith(healthWeightSyncEnabled: enabled),
    );
    return true;
  }

  Future<bool> setHealthNutritionSyncEnabled(bool enabled) async {
    if (enabled) {
      final healthService = HealthService();
      final granted = await healthService.requestNutritionPermissions();
      if (!granted) return false;
    }

    await _persistSettings(
      settings: _settings.copyWith(healthNutritionSyncEnabled: enabled),
    );
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
    await _persistSettings(
      settings: _settings.copyWith(
        waterSize1: size1,
        waterSize2: size2,
        waterSize3: size3,
        waterSize4: size4,
      ),
    );
  }

  // Dashboard card customization
  List<DashboardCard> get dashboardCards {
    if (_settings.dashboardCards.isEmpty) {
      // Return defaults if not customized
      return DashboardCardIds.defaultCards;
    }
    return _settings.dashboardCards;
  }

  List<DashboardCard> get visibleDashboardCards =>
      dashboardCards.where((c) => c.visible).toList();

  Future<void> setDashboardCards(List<DashboardCard> cards) async {
    await _persistSettings(settings: _settings.copyWith(dashboardCards: cards));
  }

  Future<void> toggleDashboardCardVisibility(String id) async {
    final cards = List<DashboardCard>.from(dashboardCards);
    final index = cards.indexWhere((c) => c.id == id);
    if (index != -1) {
      cards[index] = cards[index].copyWith(visible: !cards[index].visible);
      await setDashboardCards(cards);
    }
  }

  Future<void> reorderDashboardCards(int oldIndex, int newIndex) async {
    final cards = List<DashboardCard>.from(dashboardCards);
    if (newIndex > oldIndex) newIndex--;
    final card = cards.removeAt(oldIndex);
    cards.insert(newIndex, card);
    await setDashboardCards(cards);
  }

  Future<void> resetDashboardCards() async {
    await setDashboardCards([]); // Empty list triggers defaults
  }

  // Custom meal types
  List<CustomMealType> get mealTypes {
    if (_settings.customMealTypes.isEmpty) {
      // Return defaults if not customized, with migrated reminder times
      return _migrateDefaultMealTypes();
    }
    return List.from(_settings.customMealTypes)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Migrate old reminder times to default meal types
  List<CustomMealType> _migrateDefaultMealTypes() {
    return CustomMealType.defaults.map((m) {
      String? reminder;
      if (m.id == 'breakfast') reminder = _settings.breakfastReminderTime;
      if (m.id == 'lunch') reminder = _settings.lunchReminderTime;
      if (m.id == 'dinner') reminder = _settings.dinnerReminderTime;
      if (reminder != null) {
        return m.copyWith(reminderTime: reminder);
      }
      return m;
    }).toList();
  }

  CustomMealType? getMealType(String id) {
    try {
      return mealTypes.firstWhere((m) => m.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> setMealTypes(List<CustomMealType> types) async {
    _settings = _settings.copyWith(customMealTypes: types);
    await _storage.saveSettings(_settings);
    await _updateNotificationsFromMealTypes();
    notifyListeners();
  }

  Future<void> addMealType(CustomMealType mealType) async {
    final types = List<CustomMealType>.from(
      _settings.customMealTypes.isEmpty
          ? CustomMealType.defaults
          : _settings.customMealTypes,
    );
    types.add(mealType);
    await setMealTypes(types);
  }

  Future<void> updateMealType(CustomMealType mealType) async {
    final types = List<CustomMealType>.from(
      _settings.customMealTypes.isEmpty
          ? CustomMealType.defaults
          : _settings.customMealTypes,
    );
    final index = types.indexWhere((m) => m.id == mealType.id);
    if (index != -1) {
      types[index] = mealType;
      await setMealTypes(types);
    }
  }

  Future<void> removeMealType(String id) async {
    final types = List<CustomMealType>.from(
      _settings.customMealTypes.isEmpty
          ? CustomMealType.defaults
          : _settings.customMealTypes,
    );
    // Only remove if not a default meal
    types.removeWhere((m) => m.id == id && !m.isDefault);
    await setMealTypes(types);
  }

  Future<void> reorderMealTypes(int oldIndex, int newIndex) async {
    final types = List<CustomMealType>.from(mealTypes);
    if (newIndex > oldIndex) newIndex--;
    final type = types.removeAt(oldIndex);
    types.insert(newIndex, type);

    // Update sort orders
    final updatedTypes = <CustomMealType>[];
    for (var i = 0; i < types.length; i++) {
      updatedTypes.add(types[i].copyWith(sortOrder: i));
    }

    await setMealTypes(updatedTypes);
  }

  /// Update notifications based on meal type reminders
  Future<void> _updateNotificationsFromMealTypes() async {
    if (!_settings.remindersEnabled) {
      await _notifications.cancelAllReminders();
      return;
    }

    // Cancel existing reminders
    await _notifications.cancelAllReminders();

    // Schedule new reminders based on meal types
    final types = mealTypes;
    for (var i = 0; i < types.length; i++) {
      final meal = types[i];
      final reminderTime = TimeUtils.parseStoredTime(meal.reminderTime);
      if (reminderTime != null) {
        await _notifications.scheduleMealReminder(
          id: i,
          title: 'Time for ${meal.name}!',
          body: 'Don\'t forget to log your ${meal.name.toLowerCase()}',
          hour: reminderTime.hour,
          minute: reminderTime.minute,
        );
      }
    }
  }
}
