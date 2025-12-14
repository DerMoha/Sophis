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
    gender: json['gender'] != null ? Gender.values[json['gender']] : null,
    activityLevel: json['activityLevel'] != null
        ? ActivityLevel.values[json['activityLevel']]
        : null,
    goal: json['goal'] != null ? Goal.values[json['goal']] : null,
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
  }) => UserProfile(
    weight: weight ?? this.weight,
    height: height ?? this.height,
    age: age ?? this.age,
    gender: gender ?? this.gender,
    activityLevel: activityLevel ?? this.activityLevel,
    goal: goal ?? this.goal,
    targetWeight: targetWeight ?? this.targetWeight,
  );
}
