import 'package:sophis/services/gemini/models/nutrition_label_result.dart';

class NutritionLabelParser {
  static final RegExp _kcalPattern = RegExp(
    r'(\d+[\.,]?\d*)\s*(?:kcal|Cal|Kal)',
    caseSensitive: false,
  );
  static final RegExp _calKeywordPattern = RegExp(
    r'(?:Calories|calories|Energie|energie|Energy|energy|Brennwert|brennwert)\D*?(\d+[\.,]?\d*)',
    caseSensitive: false,
  );
  static final RegExp _kjPattern = RegExp(
    r'(\d+[\.,]?\d*)\s*kJ',
    caseSensitive: false,
  );
  static final RegExp _proteinRegexp = RegExp(
    r'(?:Protein|Eiwei[ßs]|Eiweiss|Protéines|proteine)',
    caseSensitive: false,
  );
  static final RegExp _carbsRegexp = RegExp(
    r'(?:Kohlenhydrate|Carbohydrates|Carbohydrate|Carbs|Glucides|glucides)',
    caseSensitive: false,
  );
  static final RegExp _fatRegexp = RegExp(
    r'(?:Fett|Fat|Matières\s*grasses|matieres\s*grasses|lipides|Lipides)',
    caseSensitive: false,
  );
  static final RegExp _fiberRegexp = RegExp(
    r'(?:Ballaststoffe|Fiber|Fibre|Fibres|fibres)',
    caseSensitive: false,
  );
  static final RegExp _numberPattern = RegExp(
    r'(\d+[\.,]?\d*)',
  );
  static final RegExp _servingSizeLinePattern = RegExp(
    r'(?:Portion|Serving|Portionsgröße|serving\s*size)\D*?(\d+[\.,]?\d*)\s*(?:g|ml)',
    caseSensitive: false,
  );
  static final RegExp _servingParentheticalPattern = RegExp(
    r'\((\d+[\.,]?\d*)\s*(?:g|ml)\)',
  );
  static final RegExp _perServingKeywordPattern = RegExp(
    r'(?:per|pro|je)\s*(?:Portion|Serving|portion|serving)|Amount\s+Per\s+Serving',
    caseSensitive: false,
  );
  static final RegExp _per100Pattern = RegExp(
    r'(?:per|pro|je|pour)\s*100\s*(?:g|ml)',
    caseSensitive: false,
  );
  static final RegExp _subLineRegexp = RegExp(
    r'(?:davon|gesätt|satur|ungesätt|unsatur|mehrfach|poly|einfach|mono|trans|of\s*which|dont|y\s*compris|sugars|zucker|cholest|sodium|salt|salz|sucre)',
    caseSensitive: false,
  );
  static final RegExp _isNutritionLabelPattern = RegExp(
    r'(?:Energie|Energy|Brennwert|Calories|Eiwei[ßs]|Protein|Kohlenhydrate|Carbohydrate|Fett|Fat|Ballaststoffe|Fiber|fibre|Nährwert|Nutrition)',
    caseSensitive: false,
  );

  static NutritionLabelResult? parse(String ocrText) {
    ocrText = _normalizeOcrText(ocrText);
    if (!_isNutritionLabelPattern.hasMatch(ocrText)) {
      return null;
    }

    final lines = ocrText.split('\n');
    final isPerServing = _perServingKeywordPattern.hasMatch(ocrText) &&
        !_per100Pattern.hasMatch(ocrText);

    String? productLine1;
    String? productLine2;
    for (final line in lines.take(10)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (_isNutritionLabelPattern.hasMatch(trimmed)) break;
      if (RegExp(r'^\d').hasMatch(trimmed)) continue;
      if (trimmed.length > 2 && trimmed.length < 60) {
        if (productLine1 == null) {
          productLine1 = trimmed;
        } else if (productLine2 == null) {
          productLine2 = trimmed;
          break;
        }
      }
    }

    final flatText = lines.join(' ');

    var calories = _extractKcal(flatText);
    if (calories == null && _kjPattern.hasMatch(flatText)) {
      final kjMatch = _kjPattern.firstMatch(flatText)!;
      final kj = _parseNumber(kjMatch.group(1)!);
      calories = kj * 0.239;
    }

    final protein = _extractMacro(lines, _proteinRegexp);
    final carbs = _extractMacro(lines, _carbsRegexp);
    final fat = _extractMacro(lines, _fatRegexp);
    final fiber = _extractMacro(lines, _fiberRegexp);

    final foundCount = [
      calories != null ? 1 : 0,
      protein != null ? 1 : 0,
      carbs != null ? 1 : 0,
      fat != null ? 1 : 0,
      fiber != null ? 1 : 0,
    ].fold<int>(0, (a, b) => a + b);

    if (foundCount < 3) {
      return null;
    }

    final servingSizeG = _extractServingSize(lines);
    final servingName = _extractServingName(lines);

    final double? adjustedCalories;
    final double? adjustedProtein;
    final double? adjustedCarbs;
    final double? adjustedFat;
    final double? adjustedFiber;

    if (isPerServing && servingSizeG != null && servingSizeG > 0) {
      final scale = 100 / servingSizeG;
      adjustedCalories = (calories ?? 0) * scale;
      adjustedProtein = (protein ?? 0) * scale;
      adjustedCarbs = (carbs ?? 0) * scale;
      adjustedFat = (fat ?? 0) * scale;
      adjustedFiber = (fiber ?? 0) * scale;
    } else {
      adjustedCalories = calories;
      adjustedProtein = protein;
      adjustedCarbs = carbs;
      adjustedFat = fat;
      adjustedFiber = fiber;
    }

    return NutritionLabelResult(
      productName: productLine1 != null && productLine2 != null
          ? '$productLine1 $productLine2'
          : productLine1,
      brand: null,
      caloriesPer100g: adjustedCalories ?? 0,
      proteinPer100g: adjustedProtein ?? 0,
      carbsPer100g: adjustedCarbs ?? 0,
      fatPer100g: adjustedFat ?? 0,
      fiberPer100g: adjustedFiber ?? 0,
      servingSizeG: servingSizeG,
      servingName: servingName,
    );
  }

  static double? _extractKcal(String text) {
    final match = _kcalPattern.firstMatch(text);
    if (match != null) {
      final value = _parseNumber(match.group(1)!);
      if (value <= 950) return value;
    }
    final calMatch = _calKeywordPattern.firstMatch(text);
    if (calMatch != null) {
      final after = text.substring(calMatch.end).trimLeft();
      if (after.toLowerCase().startsWith('kj')) {
        return null;
      }
      final value = _parseNumber(calMatch.group(1)!);
      if (value <= 950) return value;
    }
    return null;
  }

  static double? _extractMacro(List<String> lines, RegExp keywordPattern) {
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (_subLineRegexp.hasMatch(line)) continue;
      if (!keywordPattern.hasMatch(line)) continue;
      final match = _numberPattern.firstMatch(line);
      if (match == null) continue;
      final value = _parseNumber(match.group(1)!);
      if (value > 100) continue;
      return value;
    }
    return null;
  }

  static double? _extractServingSize(List<String> lines) {
    for (final rawLine in lines) {
      final line = rawLine.trim();

      final parenthetical = _servingParentheticalPattern.firstMatch(line);
      if (parenthetical != null) {
        final value = _parseNumber(parenthetical.group(1)!);
        if (value > 0) return value;
      }

      final direct = _servingSizeLinePattern.firstMatch(line);
      if (direct != null) {
        final value = _parseNumber(direct.group(1)!);
        if (value > 0) return value;
      }
    }
    return null;
  }

  static String? _extractServingName(List<String> lines) {
    for (final rawLine in lines) {
      final line = rawLine.trim();
      final match = _servingSizeLinePattern.firstMatch(line);
      if (match != null) {
        final cleaned = match
            .group(0)!
            .replaceAll(RegExp(r'\d+[\.,]?\d*\s*(?:g|ml)'), '')
            .trim();
        return cleaned.isNotEmpty ? cleaned : null;
      }
    }
    return null;
  }

  static double _parseNumber(String raw) {
    final normalized = raw.replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  static String _normalizeOcrText(String text) {
    final characters = text.split('');
    for (var index = 0; index < characters.length; index++) {
      final character = characters[index];
      if (character != 'O' &&
          character != 'o' &&
          character != 'I' &&
          character != 'l') {
        continue;
      }
      final previous = index > 0 ? characters[index - 1] : '';
      final next = index + 1 < characters.length ? characters[index + 1] : '';
      final nextLooksNumeric = RegExp(r'[\d\.,]').hasMatch(next);
      final previousLooksNumeric = RegExp(r'[\d\.,]').hasMatch(previous);
      if (!previousLooksNumeric && !nextLooksNumeric) continue;
      characters[index] = character == 'O' || character == 'o' ? '0' : '1';
    }
    return characters.join();
  }
}
