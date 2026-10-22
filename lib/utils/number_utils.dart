class NumberUtils {
  /// Parses a measurement entered with either a decimal comma or decimal dot.
  /// Grouping separators are deliberately unsupported in editable quantities.
  static double? parseInput(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (!RegExp(r'^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)$')
        .hasMatch(normalized)) {
      return null;
    }
    final parsed = double.tryParse(normalized);
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  /// Formats a numeric value for display.
  /// - 1 decimal place if the absolute value is <= 100
  /// - 0 decimal places if the absolute value is > 100
  static String format(num value) {
    final abs = value.abs();
    if (abs <= 100) {
      return value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    }
    return value.toStringAsFixed(0);
  }

  /// Formats a nutrient value (protein, carbs, fat) for display.
  /// Uses [format] rules.
  static String formatNutrient(num value) => format(value);

  /// Formats a calorie value for display.
  /// Always rounds to 0 decimal places.
  static String formatCalories(num value) => value.toStringAsFixed(0);
}
