import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../models/custom_meal_type.dart';
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

  bool get showMealMacros => _settings.showMealMacros;

  Future<void> setShowMealMacros(bool enabled) async {
    _settings = _settings.copyWith(showMealMacros: enabled);
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
    _settings = _settings.copyWith(dashboardCards: cards);
    await _storage.saveSettings(_settings);
    notifyListeners();
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
        : _settings.customMealTypes
    );
    types.add(mealType);
    await setMealTypes(types);
  }

  Future<void> updateMealType(CustomMealType mealType) async {
    final types = List<CustomMealType>.from(
      _settings.customMealTypes.isEmpty
        ? CustomMealType.defaults
        : _settings.customMealTypes
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
        : _settings.customMealTypes
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
      if (meal.reminderTime != null) {
        final parts = meal.reminderTime!.split(':');
        if (parts.length == 2) {
          await _notifications.scheduleMealReminder(
            id: i,
            title: 'Time for ${meal.name}!',
            body: 'Don\'t forget to log your ${meal.name.toLowerCase()}',
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      }
    }
  }
}
