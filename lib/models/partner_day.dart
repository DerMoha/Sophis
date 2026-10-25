import 'package:intl/intl.dart';

import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/nutrition_goals.dart';
import 'package:sophis/models/nutrition_totals.dart';

/// One person's diary day as shared with their partner.
final class PartnerDay {
  final String date;
  final NutritionGoals? goals;
  final double burned;
  final List<FoodEntry> entries;

  PartnerDay({
    required this.date,
    required this.goals,
    required this.burned,
    required List<FoodEntry> entries,
  }) : entries = List.unmodifiable(entries);

  static String key(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  NutritionTotals get totals => entries.fold(
        NutritionTotals.zero,
        (sum, entry) =>
            sum +
            NutritionTotals(
              calories: entry.calories,
              protein: entry.protein,
              carbs: entry.carbs,
              fat: entry.fat,
              fiber: entry.fiber,
            ),
      );

  /// Same formula as the own dashboard: goal minus eaten plus burned.
  double? get remainingCalories {
    final target = goals;
    return target == null ? null : target.calories - totals.calories + burned;
  }

  /// Local food-library links stay private; only diary content is shared.
  Map<String, dynamic> toJson() => {
        'date': date,
        'goals': goals?.toJson(),
        'burned': burned,
        'entries': [
          for (final entry in entries) entry.toJson()..remove('sourceFoodId'),
        ],
      };

  factory PartnerDay.fromJson(Map<String, dynamic> json) => PartnerDay(
        date: json['date'] as String,
        goals: json['goals'] == null
            ? null
            : NutritionGoals.fromJson(
                Map<String, dynamic>.from(json['goals'] as Map),
              ),
        burned: (json['burned'] as num?)?.toDouble() ?? 0,
        entries: [
          for (final raw in json['entries'] as List? ?? const [])
            FoodEntry.fromJson(Map<String, dynamic>.from(raw as Map)),
        ],
      );
}
