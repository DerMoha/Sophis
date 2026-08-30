enum Gender { male, female, other }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

enum Goal { lose, maintain, gain }

/// User profile for TDEE calculation
class UserProfile {
  final double? weight;
  final double? height;
  final int? age;
  final Gender? gender;
  final ActivityLevel? activityLevel;
  final Goal? goal;
  final double? targetWeight;

  const UserProfile({
    this.weight,
    this.height,
    this.age,
    this.gender,
    this.activityLevel,
    this.goal,
    this.targetWeight,
  });

  /// BMR using Mifflin-St Jeor equation
  double? get bmr {
    if (weight == null || height == null || age == null || gender == null) {
      return null;
    }
    if (gender == Gender.male) {
      return (10 * weight!) + (6.25 * height!) - (5 * age!) + 5;
    } else {
      return (10 * weight!) + (6.25 * height!) - (5 * age!) - 161;
    }
  }

  /// Total Daily Energy Expenditure
  double? get tdee {
    final baseBmr = bmr;
    if (baseBmr == null || activityLevel == null) return null;

    final multipliers = {
      ActivityLevel.sedentary: 1.2,
      ActivityLevel.light: 1.375,
      ActivityLevel.moderate: 1.55,
      ActivityLevel.active: 1.725,
      ActivityLevel.veryActive: 1.9,
    };
    return baseBmr * multipliers[activityLevel]!;
  }

  /// Suggested calorie goal based on TDEE and goal
  double? get suggestedCalories {
    final baseTdee = tdee;
    if (baseTdee == null || goal == null) return null;

    switch (goal!) {
      case Goal.lose:
        return baseTdee - 500;
      case Goal.maintain:
        return baseTdee;
      case Goal.gain:
        return baseTdee + 300;
    }
  }

  Map<String, dynamic> toJson() => {
        'weight': weight,
        'height': height,
        'age': age,
        'gender': gender?.index,
        'activityLevel': activityLevel?.index,
        'goal': goal?.index,
        'targetWeight': targetWeight,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        weight: (json['weight'] as num?)?.toDouble(),
        height: (json['height'] as num?)?.toDouble(),
        age: json['age'] as int?,
        gender: _genderFromJson(json['gender']),
        activityLevel: _activityLevelFromJson(json['activityLevel']),
        goal: _goalFromJson(json['goal']),
        targetWeight: (json['targetWeight'] as num?)?.toDouble(),
      );

  UserProfile copyWith({
    double? weight,
    double? height,
    int? age,
    Gender? gender,
    ActivityLevel? activityLevel,
    Goal? goal,
    double? targetWeight,
  }) =>
      UserProfile(
        weight: weight ?? this.weight,
        height: height ?? this.height,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        activityLevel: activityLevel ?? this.activityLevel,
        goal: goal ?? this.goal,
        targetWeight: targetWeight ?? this.targetWeight,
      );
}

Gender? _genderFromJson(Object? value) {
  if (value is String) {
    return switch (value) {
      'male' => Gender.male,
      'female' => Gender.female,
      'other' => Gender.other,
      _ => null,
    };
  }
  if (value is num) {
    final index = value.toInt();
    if (index >= 0 && index < Gender.values.length) {
      return Gender.values[index];
    }
  }
  return null;
}

ActivityLevel? _activityLevelFromJson(Object? value) {
  if (value is String) {
    return switch (value) {
      'sedentary' => ActivityLevel.sedentary,
      'light' => ActivityLevel.light,
      'moderate' => ActivityLevel.moderate,
      'active' => ActivityLevel.active,
      'veryActive' => ActivityLevel.veryActive,
      _ => null,
    };
  }
  if (value is num) {
    final index = value.toInt();
    if (index >= 0 && index < ActivityLevel.values.length) {
      return ActivityLevel.values[index];
    }
  }
  return null;
}

Goal? _goalFromJson(Object? value) {
  if (value is String) {
    return switch (value) {
      'lose' => Goal.lose,
      'maintain' => Goal.maintain,
      'gain' => Goal.gain,
      _ => null,
    };
  }
  if (value is num) {
    final index = value.toInt();
    if (index >= 0 && index < Goal.values.length) {
      return Goal.values[index];
    }
  }
  return null;
}
