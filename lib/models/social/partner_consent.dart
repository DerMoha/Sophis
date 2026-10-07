import 'package:sophis/models/food_entry.dart';
import 'package:sophis/models/nutrition_totals.dart';

/// Half-open periods based on immutable original logging time, not meal date or
/// edit time. Retain closed periods to distinguish eligible edits from backfill.
final class SharingPeriod {
  final DateTime start;
  final DateTime? end;

  SharingPeriod({required this.start, this.end}) {
    if (end != null && end!.isBefore(start)) {
      throw ArgumentError('Sharing period ends before it starts');
    }
  }

  bool contains(DateTime time) =>
      !time.isBefore(start) && (end == null || time.isBefore(end!));
}

final class PartnerSourceEntry {
  final FoodEntry entry;
  final DateTime originallyLoggedAt;

  const PartnerSourceEntry({
    required this.entry,
    required this.originallyLoggedAt,
  });
}

final class PartnerConsent {
  final String connectionId;
  final bool shareMeals;
  final bool shareDailySummary;
  final bool sharePhotos;
  final bool disconnected;
  final List<SharingPeriod> periods;

  PartnerConsent({
    required this.connectionId,
    required this.shareMeals,
    required this.shareDailySummary,
    required this.sharePhotos,
    required List<SharingPeriod> periods,
    this.disconnected = false,
  }) : periods = List.unmodifiable(periods) {
    for (var index = 0; index < periods.length; index++) {
      final current = periods[index];
      if (index > 0) {
        final previousEnd = periods[index - 1].end;
        if (previousEnd == null || current.start.isBefore(previousEnd)) {
          throw ArgumentError('Sharing periods overlap');
        }
      }
    }
  }

  bool get paused => periods.isEmpty || periods.last.end != null;

  bool eligible(PartnerSourceEntry source) =>
      !disconnected &&
      periods.any((period) => period.contains(source.originallyLoggedAt));

  bool shouldSendMeal(PartnerSourceEntry source) =>
      shareMeals && !paused && eligible(source);

  /// Deletes/revocations bypass pause and sharing toggles. Server must still
  /// verify the author and connection; this is a client projection, not auth.
  bool get shouldSendPrivacyRemoval => true;

  /// Paused summaries remain frozen remotely. On resume recompute only the
  /// entries originally logged in active periods, including activation day.
  NutritionTotals? summaryForDate(
    List<PartnerSourceEntry> sources,
    DateTime localDate,
  ) {
    if (!shareDailySummary || disconnected || paused) return null;
    var calories = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0;
    for (final source in sources) {
      final date = source.entry.timestamp;
      if (!eligible(source) ||
          date.year != localDate.year ||
          date.month != localDate.month ||
          date.day != localDate.day) {
        continue;
      }
      calories += source.entry.calories;
      protein += source.entry.protein;
      carbs += source.entry.carbs;
      fat += source.entry.fat;
    }
    return NutritionTotals(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
  }
}
