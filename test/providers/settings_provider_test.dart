import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sophis/models/app_settings.dart';
import 'package:sophis/models/custom_meal_type.dart';

import '../helpers/test_services.dart';

void main() {
  group('SettingsProvider', () {
    test('persisted preferences and secure credentials', () async {
      final storage = await createTestStorage();
      final notifications = createMockNotificationService();
      final provider = await createTestSettingsProvider(
        storage: storage,
        notifications: notifications,
      );

      await provider.setThemeMode(ThemeMode.dark);
      await provider.setLocale('de');
      await provider.setAIMode(AIMode.cloud);
      await provider.setGeminiApiKey('gemini-key');
      await provider.setOffCredentials('off-user', 'off-password');
      await provider.setWaterGoal(2400);
      await provider.setUnitSystem(UnitSystem.imperial);
      await provider.setWaterSizes(100, 200, 300, 400);
      await provider.setShowMealMacros(true);
      await provider.setShowSupplements(false);
      await provider.setQuickActionSize(QuickActionSize.large);
      await provider.setProgressPhotoLockEnabled(true);

      final settings = storage.loadSettings();
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.localeOverride, 'de');
      expect(settings.aiMode, AIMode.cloud);
      expect(settings.waterGoalMl, 2400);
      expect(settings.unitSystem, UnitSystem.imperial);
      expect(settings.waterSize1, 100);
      expect(settings.showMealMacros, isTrue);
      expect(settings.showSupplements, isFalse);
      expect(settings.quickActionSize, QuickActionSize.large);
      expect(settings.progressPhotoLockEnabled, isTrue);
      expect(await storage.loadApiKey(), 'gemini-key');
      expect(await storage.loadOffUserId(), 'off-user');
      expect(await storage.loadOffPassword(), 'off-password');
    });

    test('respected reminder and health permission denials', () async {
      final notifications = createMockNotificationService();
      when(() => notifications.requestPermissions())
          .thenAnswer((_) async => false);
      final health = FakeHealthService(
        permissionsGranted: false,
        weightPermissionsGranted: false,
        nutritionPermissionsGranted: false,
      );
      final provider = await createTestSettingsProvider(
        notifications: notifications,
        healthService: health,
      );

      await provider.setRemindersEnabled(true);
      expect(provider.remindersEnabled, isFalse);
      expect(await provider.setHealthSyncEnabled(true), isFalse);
      expect(await provider.setHealthWeightSyncEnabled(true), isFalse);
      expect(await provider.setHealthNutritionSyncEnabled(true), isFalse);
      expect(provider.healthSyncEnabled, isFalse);
      expect(provider.healthWeightSyncEnabled, isFalse);
      expect(provider.healthNutritionSyncEnabled, isFalse);

      when(() => notifications.requestPermissions())
          .thenAnswer((_) async => true);
      health
        ..permissionsGranted = true
        ..weightPermissionsGranted = true
        ..nutritionPermissionsGranted = true;

      await provider.setBreakfastReminder('08:30');
      await provider.setRemindersEnabled(true);
      expect(provider.remindersEnabled, isTrue);
      expect(await provider.setHealthSyncEnabled(true), isTrue);
      expect(await provider.setHealthWeightSyncEnabled(true), isTrue);
      expect(await provider.setHealthNutritionSyncEnabled(true), isTrue);
      expect(provider.healthSyncEnabled, isTrue);
      expect(provider.healthWeightSyncEnabled, isTrue);
      expect(provider.healthNutritionSyncEnabled, isTrue);
      verify(
        () => notifications.updateMealReminders(
          enabled: true,
          breakfastTime: '08:30',
          lunchTime: null,
          dinnerTime: null,
        ),
      ).called(1);
    });

    test('managed dashboard cards and custom meal types', () async {
      final provider = await createTestSettingsProvider();

      await provider.setDashboardCards(
        const [
          DashboardCard(id: DashboardCardIds.foodDiary),
          DashboardCard(id: DashboardCardIds.weight),
        ],
      );
      await provider.toggleDashboardCardVisibility(DashboardCardIds.weight);
      await provider.reorderDashboardCards(1, 0);

      expect(provider.dashboardCards.first.id, DashboardCardIds.weight);
      expect(provider.dashboardCards.first.visible, isFalse);
      expect(
        provider.visibleDashboardCards.single.id,
        DashboardCardIds.foodDiary,
      );

      const brunch = CustomMealType(
        id: 'brunch',
        name: 'Brunch',
        reminderTime: '10:30',
        sortOrder: 4,
      );
      await provider.addMealType(brunch);
      expect(provider.getMealType('brunch')?.name, 'Brunch');

      await provider.updateMealType(brunch.copyWith(name: 'Late Brunch'));
      expect(provider.getMealType('brunch')?.name, 'Late Brunch');

      await provider.removeMealType('breakfast');
      expect(provider.getMealType('breakfast'), isNotNull);

      await provider.removeMealType('brunch');
      expect(provider.getMealType('brunch'), isNull);
    });
  });
}
