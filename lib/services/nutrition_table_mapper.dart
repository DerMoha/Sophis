import 'package:sophis/models/nutrition_unit.dart';
import 'package:sophis/services/gemini/models/nutrition_label_result.dart';

/// Maps a nutrition table that is already split into rows and cells (Apple's
/// document recognition) to per-100 values.
///
/// No geometry guessing is needed: row labels are matched by keyword and the
/// value is taken from the per-100 column when the header names one, else from
/// the first value after the label. Fields that are not found stay absent.
class NutritionTableMapper {
  const NutritionTableMapper._();

  static final _per100 = RegExp(
    r'(?:pro|per|je|in|ø|o|0|ø/|/)?\s*100\s*(g|ml)\b',
    caseSensitive: false,
  );
  static final _portion = RegExp(
    r'(?:portion|serving|packung)\D{0,12}(\d+(?:[.,]\d+)?)\s*(g|ml)\b',
    caseSensitive: false,
  );
  static final _number = RegExp(r'(<\s*)?(\d+(?:[.,]\d+)?)');
  static final _kcal =
      RegExp(r'(\d+(?:[.,]\d+)?)\s*kcal', caseSensitive: false);
  static final _kj = RegExp(r'(\d+(?:[.,]\d+)?)\s*kj', caseSensitive: false);

  /// Returns the best reading across [tables], or null when no table has a
  /// recognizable nutrient row.
  static NutritionLabelResult? map(List<List<List<String>>> tables) {
    NutritionLabelResult? best;
    for (final table in tables) {
      final label = _mapTable(table);
      if (label == null) continue;
      if (best == null ||
          label.presentFields.length > best.presentFields.length) {
        best = label;
      }
    }
    return best;
  }

  static NutritionLabelResult? _mapTable(List<List<String>> rows) {
    int? valueColumn;
    var unit = NutritionUnit.gram;
    double? serving;
    for (final row in rows) {
      for (var column = 0; column < row.length; column++) {
        final cell = row[column];
        final per100 = _per100.firstMatch(cell);
        if (per100 != null && valueColumn == null) {
          valueColumn = column;
          if (per100.group(1)!.toLowerCase() == 'ml') {
            unit = NutritionUnit.milliliter;
          }
        }
        final portion = _portion.firstMatch(cell);
        if (portion != null) serving ??= _parse(portion.group(1)!);
      }
      if (valueColumn != null) break;
    }

    final values = <NutritionLabelField, double>{};
    final upperBounds = <NutritionLabelField>{};
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final match = _findField(row);
      if (match == null || values.containsKey(match.field)) continue;
      final (field, labelColumn, remainder) =
          (match.field, match.column, match.remainder);

      if (field == NutritionLabelField.calories) {
        final text = _valueText(row, labelColumn, valueColumn, remainder);
        // Some labels print kJ and kcal on two rows under one "Energie" label.
        final next =
            index + 1 < rows.length && _findField(rows[index + 1]) == null
                ? _valueText(rows[index + 1], -1, valueColumn, '')
                : null;
        final kj = _match(_kj, text);
        // "Brennwert kJ/kcal | 918/216": the units are in the label cell.
        final pair =
            RegExp(r'kj\s*/\s*kcal').hasMatch(_normalize(row[labelColumn]))
                ? RegExp(r'\d+(?:[.,]\d+)?\s*/\s*(\d+(?:[.,]\d+)?)')
                    .firstMatch(text ?? '')
                : null;
        final kcal = (pair == null ? null : _parse(pair.group(1)!)) ??
            _match(_kcal, text) ??
            _match(_kcal, next) ??
            (kj == null ? null : (kj / 4.184).roundToDouble());
        if (kcal != null) values[field] = kcal;
        continue;
      }

      final text = _valueText(row, labelColumn, valueColumn, remainder);
      final number = text == null ? null : _number.firstMatch(text);
      if (number == null) continue;
      final value = _parse(number.group(2)!);
      if (value == null) continue;
      values[field] = value;
      if (number.group(1) != null) upperBounds.add(field);
    }
    if (values.isEmpty) return null;

    return NutritionLabelResult(
      caloriesPer100g: values[NutritionLabelField.calories] ?? 0,
      proteinPer100g: values[NutritionLabelField.protein] ?? 0,
      carbsPer100g: values[NutritionLabelField.carbs] ?? 0,
      fatPer100g: values[NutritionLabelField.fat] ?? 0,
      fiberPer100g: values[NutritionLabelField.fiber] ?? 0,
      nutritionUnit: unit,
      servingSizeG: serving,
      presentFields: values.keys.toSet(),
      upperBoundFields: upperBounds,
      explicitUnitFields: values.keys.toSet(),
    );
  }

  static ({NutritionLabelField field, int column, String remainder})?
      _findField(List<String> row) {
    for (var column = 0; column < row.length; column++) {
      final normalized = _normalize(row[column]);
      final field = _fieldFor(normalized);
      if (field == null) continue;
      // Text after the keyword, for labels and values merged into one cell.
      final digit = row[column].indexOf(RegExp(r'[<\d]'));
      final remainder = digit < 0 ? '' : row[column].substring(digit);
      return (field: field, column: column, remainder: remainder);
    }
    return null;
  }

  static NutritionLabelField? _fieldFor(String text) {
    // "davon" / "of which" rows (sugars, saturates) are sub-rows, never totals.
    // Fragments too ("avon", "gesatt"), for labels cut off at the edge.
    if (RegExp(r'avon|of which|dont|saur|satur|gesatt|zucker|sugar')
        .hasMatch(text)) {
      return null;
    }
    // Distinctive inner fragments also match names that OCR clipped or
    // garbled at the start ("rergie", "ehlenhydrate", "ciweiß").
    if (RegExp(r'ergie|brennwert|energy|kalorien|calor|energia|kj\s*/\s*kcal')
        .hasMatch(text)) {
      return NutritionLabelField.calories;
    }
    if (RegExp(r'^(fett|fat|matieres grasses|lipides|grassi|vetten|grasas)\b')
        .hasMatch(text)) {
      return NutritionLabelField.fat;
    }
    if (RegExp(r'hydrat|glucides|carboidrati|carbohidrat').hasMatch(text)) {
      return NutritionLabelField.carbs;
    }
    if (RegExp(r'aststoff|fibre|fiber|vezels|fibra').hasMatch(text)) {
      return NutritionLabelField.fiber;
    }
    if (RegExp(r'weiß|weiss|eiwei|protein|eiwit').hasMatch(text)) {
      return NutritionLabelField.protein;
    }
    return null;
  }

  static String _normalize(String text) => text
      .trim()
      .toLowerCase()
      .replaceAll('ä', 'a')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e');

  /// The text holding this row's per-100 value. A value printed in the label
  /// cell itself wins: document recognition often merges label and value.
  static String? _valueText(
    List<String> row,
    int labelColumn,
    int? valueColumn,
    String remainder,
  ) {
    if (remainder.isNotEmpty) return remainder;
    if (valueColumn != null &&
        valueColumn > labelColumn &&
        valueColumn < row.length &&
        row[valueColumn].contains(RegExp(r'\d'))) {
      return row[valueColumn];
    }
    for (var column = labelColumn + 1; column < row.length; column++) {
      if (row[column].contains(RegExp(r'\d'))) return row[column];
    }
    return null;
  }

  static double? _match(RegExp pattern, String? text) {
    if (text == null) return null;
    final match = pattern.firstMatch(text);
    return match == null ? null : _parse(match.group(1)!);
  }

  static double? _parse(String text) =>
      double.tryParse(text.replaceAll(',', '.'));
}
