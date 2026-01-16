/// User statistics for gamification and streak tracking
class UserStats {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastLogDate;
  final List<String> achievements;
  final int totalDaysLogged;

  const UserStats({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastLogDate,
    this.achievements = const [],
    this.totalDaysLogged = 0,
  });

  Map<String, dynamic> toJson() => {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastLogDate': lastLogDate?.toIso8601String(),
        'achievements': achievements,
        'totalDaysLogged': totalDaysLogged,
      };

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        currentStreak: json['currentStreak'] as int? ?? 0,
        longestStreak: json['longestStreak'] as int? ?? 0,
        lastLogDate: json['lastLogDate'] != null
            ? DateTime.parse(json['lastLogDate'] as String)
            : null,
        achievements: (json['achievements'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        totalDaysLogged: json['totalDaysLogged'] as int? ?? 0,
      );

  UserStats copyWith({
    int? currentStreak,
    int? longestStreak,
    DateTime? lastLogDate,
    List<String>? achievements,
    int? totalDaysLogged,
  }) =>
      UserStats(
        currentStreak: currentStreak ?? this.currentStreak,
        longestStreak: longestStreak ?? this.longestStreak,
        lastLogDate: lastLogDate ?? this.lastLogDate,
        achievements: achievements ?? this.achievements,
        totalDaysLogged: totalDaysLogged ?? this.totalDaysLogged,
      );
}

/// Achievement definitions
class Achievements {
  static const firstLog = 'first_log';
  static const threeDayStreak = 'three_day_streak';
  static const weekWarrior = 'week_warrior';
  static const twoWeekStreak = 'two_week_streak';
  static const monthlyMaster = 'monthly_master';
  static const centurion = 'centurion';  // 100 days total

  static const List<String> all = [
    firstLog,
    threeDayStreak,
    weekWarrior,
    twoWeekStreak,
    monthlyMaster,
    centurion,
  ];
}
