import 'package:flutter/foundation.dart';
import 'package:sophis/models/user_stats.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/user_profile.dart';
import 'package:sophis/services/storage_service.dart';

class StatsStore extends ChangeNotifier {
  final StorageService _storage;

  UserStats _userStats = const UserStats();

  StatsStore(this._storage);

  UserStats get userStats => _userStats;

  void loadData(UserStats stats) {
    _userStats = stats;
    notifyListeners();
  }

  Future<void> updateStreak() async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final lastLog = _userStats.lastLogDate;

    if (lastLog != null) {
      final lastLogDate = DateTime(lastLog.year, lastLog.month, lastLog.day);
      final daysDifference = todayDate.difference(lastLogDate).inDays;

      if (daysDifference == 0) {
        return;
      } else if (daysDifference == 1) {
        _userStats = _userStats.copyWith(
          currentStreak: _userStats.currentStreak + 1,
          longestStreak: _userStats.currentStreak + 1 > _userStats.longestStreak
              ? _userStats.currentStreak + 1
              : _userStats.longestStreak,
          lastLogDate: today,
          totalDaysLogged: _userStats.totalDaysLogged + 1,
        );
      } else {
        _userStats = _userStats.copyWith(
          currentStreak: 1,
          lastLogDate: today,
          totalDaysLogged: _userStats.totalDaysLogged + 1,
        );
      }
    } else {
      _userStats = _userStats.copyWith(
        currentStreak: 1,
        longestStreak: 1,
        lastLogDate: today,
        totalDaysLogged: 1,
      );
    }

    await _checkAchievements();
    await _storage.saveUserStats(_userStats);
    notifyListeners();
  }

  Future<void> _checkAchievements() async {
    final currentAchievements = List<String>.from(_userStats.achievements);
    var newAchievements = false;

    if (!currentAchievements.contains(Achievements.firstLog) &&
        _userStats.totalDaysLogged >= 1) {
      currentAchievements.add(Achievements.firstLog);
      newAchievements = true;
    }

    if (!currentAchievements.contains(Achievements.threeDayStreak) &&
        _userStats.currentStreak >= 3) {
      currentAchievements.add(Achievements.threeDayStreak);
      newAchievements = true;
    }

    if (!currentAchievements.contains(Achievements.weekWarrior) &&
        _userStats.currentStreak >= 7) {
      currentAchievements.add(Achievements.weekWarrior);
      newAchievements = true;
    }

    if (!currentAchievements.contains(Achievements.twoWeekStreak) &&
        _userStats.currentStreak >= 14) {
      currentAchievements.add(Achievements.twoWeekStreak);
      newAchievements = true;
    }

    if (!currentAchievements.contains(Achievements.monthlyMaster) &&
        _userStats.currentStreak >= 30) {
      currentAchievements.add(Achievements.monthlyMaster);
      newAchievements = true;
    }

    if (!currentAchievements.contains(Achievements.centurion) &&
        _userStats.totalDaysLogged >= 100) {
      currentAchievements.add(Achievements.centurion);
      newAchievements = true;
    }

    if (newAchievements) {
      _userStats = _userStats.copyWith(achievements: currentAchievements);
    }
  }

  void clearAll() {
    _userStats = const UserStats();
  }
}

class GoalsStore extends ChangeNotifier {
  final StorageService _storage;

  NutritionGoals? _goals;
  UserProfile? _profile;

  GoalsStore(this._storage);

  NutritionGoals? get goals => _goals;
  UserProfile? get profile => _profile;

  void loadData(NutritionGoals? goals, UserProfile? profile) {
    _goals = goals;
    _profile = profile;
    notifyListeners();
  }

  Future<void> setGoals(NutritionGoals goals) async {
    _goals = goals;
    await _storage.saveGoals(goals);
    notifyListeners();
  }

  Future<void> setProfile(UserProfile profile) async {
    _profile = profile;
    await _storage.saveProfile(profile);
    notifyListeners();
  }

  void clearAll() {
    _goals = null;
    _profile = null;
  }
}
