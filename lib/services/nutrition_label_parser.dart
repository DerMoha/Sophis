import 'package:sophis/services/gemini/models/nutrition_label_result.dart';
import 'package:sophis/models/nutrition_label_draft.dart';
import 'package:sophis/models/nutrition_unit.dart';

import 'package:sophis/services/nutrition_ocr_document.dart';
import 'package:sophis/services/nutrition_table_region.dart';
export 'nutrition_ocr_document.dart';

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
  static final RegExp _energyKeywordPattern = RegExp(
    r'(?:Energie|Energy|Energia|Brennwert|Calories)',
    caseSensitive: false,
  );
  static final RegExp _proteinRegexp = RegExp(
    r'(?:Protein|E[il]wei[ßsb]|Eiweiss|Protéines|proteine|Eiwitten|Proteínas|Proteine|Białko|Bialko|Proteiner)',
    caseSensitive: false,
  );
  static final RegExp _carbsRegexp = RegExp(
    r'(?:Kohlenhydrate|Carbohydrates|Carbohydrate|Carbs|Glucides|Koolhydraten|Hidratos\s+de\s+carbono|Carboidrati|Węglowodany|Weglowodany|Kolhydrater)',
    caseSensitive: false,
  );
  static final RegExp _fatRegexp = RegExp(
    r'(?:Fett|Fat|Matières\s*grasses|matieres\s*grasses|lipides|Vetten|Grasas|Grassi|Tłuszcz|Tluszcz|Fedt)',
    caseSensitive: false,
  );
  static final RegExp _fiberRegexp = RegExp(
    r'(?:Ballaststoffe|Fiber|Fibre|Fibres|Vezels|Fibra|Błonnik|Blonnik|Kostfibre)',
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
    r'(?:(?:per|pro|je|pour|por|w)\s*|[øØ⌀]\s*/?\s*|/\s*|\b)100\s*(?:g|ml)\b',
    caseSensitive: false,
  );
  static final RegExp _subLineRegexp = RegExp(
    r'(?:davon|gesätt|satur|ungesätt|unsatur|mehrfach|poly|einfach|mono|trans|of\s*which|dont|y\s*compris|sugars|zucker|cholest|sodium|salt|salz|sucre)',
    caseSensitive: false,
  );
  static final RegExp _isNutritionLabelPattern = RegExp(
    r'(?:Energie|Energy|Energia|Brennwert|Calories|Calorías|E[il]wei[ßsb]|Protein|Proteínas|Białko|Kohlenhydrate|Carbohydrate|Koolhydraten|Carboidrati|Węglowodany|Fett|Fat|Vetten|Grasas|Grassi|Tłuszcz|Ballaststoffe|Fiber|Fibre|Vezels|Fibra|Błonnik|Nährwert|Nutrition|Voedingswaarde|Valor\s+nutricional|Wartość\s+odżywcza)',
    caseSensitive: false,
  );

  static bool hasPer100Heading(String text) => _per100Pattern.hasMatch(text);

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
    final nutritionUnit = _extractNutritionUnit(flatText);
    final presentFields = <NutritionLabelField>{
      if (calories != null) NutritionLabelField.calories,
      if (protein != null) NutritionLabelField.protein,
      if (carbs != null) NutritionLabelField.carbs,
      if (fat != null) NutritionLabelField.fat,
      if (fiber != null) NutritionLabelField.fiber,
    };

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
      nutritionUnit: nutritionUnit,
      servingSizeG: servingSizeG,
      servingName: servingName,
      wasServingConverted: isPerServing && servingSizeG != null,
      presentFields: presentFields,
      explicitUnitFields: _explicitUnits(lines),
      upperBoundFields: _upperBounds(lines),
    );
  }

  /// Parse as much as is safely available without manufacturing missing
  /// values. This is used by the editable review flow when a label only
  /// exposes some rows or OCR loses one of the required macros.
  static NutritionLabelDraft? parseDraft(String ocrText) {
    ocrText = _normalizeOcrText(ocrText);
    if (!_isNutritionLabelPattern.hasMatch(ocrText)) return null;

    final lines = ocrText.split('\n');
    final flatText = lines.join(' ');
    final isPerServing = _perServingKeywordPattern.hasMatch(ocrText) &&
        !_per100Pattern.hasMatch(ocrText);
    final servingAmount = _extractServingSize(lines);

    double? scaleValue(double? value) {
      if (!isPerServing || servingAmount == null || servingAmount <= 0) {
        return value;
      }
      return value == null ? null : value * 100 / servingAmount;
    }

    var calories = _extractKcal(flatText);
    if (calories == null && _kjPattern.hasMatch(flatText)) {
      final kjMatch = _kjPattern.firstMatch(flatText)!;
      calories = _parseNumber(kjMatch.group(1)!) * 0.239;
    }
    final protein = _extractMacro(lines, _proteinRegexp);
    final carbs = _extractMacro(lines, _carbsRegexp);
    final fat = _extractMacro(lines, _fatRegexp);
    final fiber = _extractMacro(lines, _fiberRegexp);
    final values = [calories, protein, carbs, fat, fiber];
    if (values.every((value) => value == null)) return null;

    String? productName;
    String? secondProductLine;
    for (final line in lines.take(10)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (_isNutritionLabelPattern.hasMatch(trimmed)) break;
      if (RegExp(r'^\d').hasMatch(trimmed)) continue;
      if (trimmed.length > 2 && trimmed.length < 60) {
        if (productName == null) {
          productName = trimmed;
        } else if (secondProductLine == null) {
          secondProductLine = trimmed;
          break;
        }
      }
    }

    return NutritionLabelDraft(
      productName: productName == null
          ? null
          : secondProductLine == null
              ? productName
              : '$productName $secondProductLine',
      upperBoundFields: _upperBounds(lines),
      caloriesPer100: scaleValue(calories),
      proteinPer100: scaleValue(protein),
      carbsPer100: scaleValue(carbs),
      fatPer100: scaleValue(fat),
      fiberPer100: scaleValue(fiber),
      nutritionUnit: _extractNutritionUnit(flatText),
      servingAmount: servingAmount,
      servingName: _extractServingName(lines),
      wasServingConverted: isPerServing && servingAmount != null,
    );
  }

  static NutritionLabelResult? parseLayout(List<NutritionOcrLine> input) {
    final region = NutritionTableRegion.locate(input);
    final lines = region == null
        ? input
        : region.lines.map(_normalizeStandaloneRowLabel).toList();
    final anchor = _findPer100Anchor(lines);
    if (anchor != null) return _parseAnchoredTable(lines, anchor);

    // Without a column heading, only use values explicitly attached to their
    // nutrient names. Nearest-row guesses can borrow unrelated package text.
    return parse(lines.map((line) => line.text).join('\n'));
  }

  // A single character can be lost in a small nutrient name (e.g. ß).
  // Only repair standalone alphabetic labels inside a detected nutrient table.
  // Never apply this to numbers, package copy, or ambiguous vocabulary matches.
  static NutritionOcrLine _normalizeStandaloneRowLabel(NutritionOcrLine line) {
    final word = line.text.trim().toLowerCase();
    if (!RegExp(r'^[a-zäöüß]{5,}$').hasMatch(word)) return line;
    const vocabulary = [
      'eiweiß',
      'protein',
      'kohlenhydrate',
      'carbohydrates',
      'ballaststoffe',
      'fiber',
      'fibre',
    ];
    if (vocabulary.contains(word)) return line;
    final matches = vocabulary
        .where(
          (candidate) =>
              _oneEditApart(word, candidate) ||
              _twoSubstitutionsWithPrefix(word, candidate),
        )
        .toList();
    if (matches.length != 1) return line;
    final label = matches.single;
    return NutritionOcrLine(
      text: label,
      top: line.top,
      height: line.height,
      left: line.left,
      right: line.right,
      tokens: line.tokens.length == 1
          ? [
              NutritionOcrToken(
                text: label,
                centerX: line.tokens.single.centerX,
                centerY: line.tokens.single.centerY,
              ),
            ]
          : line.tokens,
    );
  }

  static bool _oneEditApart(String a, String b) {
    if ((a.length - b.length).abs() > 1) return false;
    var i = 0;
    var j = 0;
    var edits = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        i++;
        j++;
        continue;
      }
      if (++edits > 1) return false;
      if (a.length >= b.length) i++;
      if (b.length >= a.length) j++;
    }
    return edits + (a.length - i) + (b.length - j) == 1;
  }

  static bool _twoSubstitutionsWithPrefix(String a, String b) {
    // Restricted to standalone alphabetic labels inside the detected table.
    // Preserve length and the first two letters; never apply this to values.
    if (a.length < 6 ||
        a.length != b.length ||
        a.substring(0, 2) != b.substring(0, 2)) {
      return false;
    }
    var differences = 0;
    for (var index = 2; index < a.length; index++) {
      if (a[index] != b[index]) differences++;
    }
    return differences == 2;
  }

  /// Reconstruct only labelled rows in the selected column. OCR block order
  /// is not table order; standalone energy cells and reference-intake footers
  /// must never compete with the labelled energy row.
  static NutritionLabelResult? _parseAnchoredTable(
    List<NutritionOcrLine> lines,
    double anchor,
  ) {
    final heading =
        lines.firstWhere((line) => _per100Pattern.hasMatch(line.text));
    final otherHeadings = lines.where(
      (line) =>
          line != heading &&
          RegExp(r'portion|serving|%\s*RI', caseSensitive: false)
              .hasMatch(line.text) &&
          (line.top - heading.top).abs() < (heading.height ?? 50) * 2,
    );
    final otherAnchors = <double>[
      for (final line in otherHeadings)
        if (line.tokens.isNotEmpty) line.tokens.first.centerX,
      for (final token in heading.tokens)
        if (RegExp(r'portion|serving', caseSensitive: false)
            .hasMatch(token.text))
          token.centerX,
    ];
    final rightAnchors = otherAnchors.where((x) => x > anchor).toList()..sort();
    final leftAnchors = otherAnchors.where((x) => x < anchor).toList()..sort();
    final right = rightAnchors.isEmpty
        ? double.infinity
        : (anchor + rightAnchors.first) / 2;
    final left = leftAnchors.isEmpty
        ? double.negativeInfinity
        : (anchor + leftAnchors.last) / 2;
    final rows = lines
        .where(
          (line) =>
              _isNutrientRow(line.text) || _subLineRegexp.hasMatch(line.text),
        )
        .where(
          (line) =>
              !_per100Pattern.hasMatch(line.text) &&
                  !_kcalPattern.hasMatch(line.text) &&
                  !_kjPattern.hasMatch(line.text) ||
              _energyKeywordPattern.hasMatch(line.text),
        )
        .toList()
      ..sort((a, b) => a.top.compareTo(b.top));
    // Estimate the label's tilt from words on the same nutrient row, including
    // subrows. Single-word labels otherwise have no baseline information.
    final slopes = <(double, double)>[];
    for (final row in rows) {
      final words = row.tokens
          .where(
            (token) =>
                token.centerY != null && !RegExp(r'\d').hasMatch(token.text),
          )
          .toList();
      if (words.length < 2) continue;
      final dx = words.last.centerX - words.first.centerX;
      if (dx.abs() < 20) continue;
      final slope = (words.last.centerY! - words.first.centerY!) / dx;
      if (slope.abs() < 0.35) slopes.add((slope, dx.abs()));
    }
    slopes.sort((a, b) => b.$2.compareTo(a.$2));
    final slope = slopes.isEmpty ? 0.0 : slopes.first.$1;
    final gaps = <double>[
      for (var i = 1; i < rows.length; i++)
        if (rows[i].top - rows[i - 1].top > 0) rows[i].top - rows[i - 1].top,
    ]..sort();
    final maxDistance = gaps.isEmpty ? 0.0 : gaps[gaps.length ~/ 2] * 0.45;
    final reconstructed = <String>['Nutrition ${heading.text}'];
    final usedCells = <NutritionOcrToken>{};
    for (final row in rows) {
      if (_subLineRegexp.hasMatch(row.text)) continue;
      final isEnergy = _energyKeywordPattern.hasMatch(row.text);
      final cells = <(String, double, NutritionOcrToken)>[];
      for (final line in lines) {
        final tokens = line.tokens
            .where((token) => token.centerX > left && token.centerX < right)
            .toList();
        if (tokens.isEmpty) continue;
        // On a combined row, strip the nutrient name but retain adjacent units.
        final firstNumber =
            tokens.indexWhere((token) => RegExp(r'\d').hasMatch(token.text));
        if (firstNumber < 0) continue;
        final valueTokens = tokens.sublist(firstNumber);
        if (usedCells.contains(valueTokens.first)) continue;
        final text =
            _normalizeOcrText(valueTokens.map((token) => token.text).join(' '))
                .replaceAll('|', '')
                .trim();
        if (isEnergy) {
          if (!_kcalPattern.hasMatch(text) && !_kjPattern.hasMatch(text)) {
            continue;
          }
        } else if (!RegExp(r'^<?\d+(?:[.,]\d+)?\s*g?$', caseSensitive: false)
            .hasMatch(text)) {
          continue;
        }
        final origin = row.tokens.firstOrNull;
        final cell = valueTokens.first;
        final rowY = origin?.centerY ?? row.top;
        final cellY = cell.centerY ?? line.top;
        final expectedY = rowY +
            (origin == null ? 0 : slope * (cell.centerX - origin.centerX));
        final distance = (cellY - expectedY).abs();
        final followingRows = rows.where(
          (other) =>
              other.top > row.top && !_subLineRegexp.hasMatch(other.text),
        );
        final energyBottom = followingRows.isEmpty
            ? row.top + maxDistance * 2
            : followingRows.first.top;
        final inEnergyBand =
            isEnergy && cellY >= rowY - maxDistance && cellY < energyBottom;
        if (distance <= maxDistance || inEnergyBand || identical(line, row)) {
          cells.add((text, distance, cell));
        }
      }
      cells.sort((a, b) {
        if (isEnergy) {
          final aKcal = _kcalPattern.hasMatch(a.$1);
          final bKcal = _kcalPattern.hasMatch(b.$1);
          if (aKcal != bKcal) return aKcal ? -1 : 1;
        }
        return a.$2.compareTo(b.$2);
      });
      if (cells.isEmpty) continue;
      // Do not guess between two adjacent rows with equally plausible alignment.
      if (!isEnergy &&
          cells.length > 1 &&
          (cells[1].$2 - cells[0].$2).abs() < maxDistance * 0.2) {
        continue;
      }
      usedCells.add(cells.first.$3);
      reconstructed.add('${_rowKeyword(row.text)} ${cells.first.$1}');
    }
    // Preserve serving metadata, but not unrelated numeric body/footer text.
    final serving =
        _extractServingSize(lines.map((line) => line.text).toList());
    if (serving != null) {
      reconstructed.add(
        'Serving size $serving ${_extractNutritionUnit(heading.text) == NutritionUnit.milliliter ? 'ml' : 'g'}',
      );
    }
    return parse(reconstructed.join('\n'));
  }

  static double? _findPer100Anchor(List<NutritionOcrLine> lines) {
    for (final line in lines) {
      if (!_per100Pattern.hasMatch(line.text)) continue;
      for (final token in line.tokens) {
        if (RegExp(r'100\s*(?:g|ml)?', caseSensitive: false)
            .hasMatch(token.text)) {
          return token.centerX;
        }
      }
    }
    return null;
  }

  static bool _isNutrientRow(String text) =>
      _proteinRegexp.hasMatch(text) ||
      _carbsRegexp.hasMatch(text) ||
      _fatRegexp.hasMatch(text) ||
      _fiberRegexp.hasMatch(text) ||
      _energyKeywordPattern.hasMatch(text) ||
      _kcalPattern.hasMatch(text) ||
      _calKeywordPattern.hasMatch(text) ||
      _kjPattern.hasMatch(text);

  static String _rowKeyword(String text) {
    if (_energyKeywordPattern.hasMatch(text) ||
        _kcalPattern.hasMatch(text) ||
        _calKeywordPattern.hasMatch(text) ||
        _kjPattern.hasMatch(text)) {
      return 'Energy';
    }
    for (final pattern in [
      _proteinRegexp,
      _carbsRegexp,
      _fatRegexp,
      _fiberRegexp,
    ]) {
      final match = pattern.firstMatch(text);
      if (match != null) return match.group(0)!;
    }
    return text;
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

  static Set<NutritionLabelField> _explicitUnits(List<String> lines) {
    final fields = <NutritionLabelField>{};
    for (final entry in {
      NutritionLabelField.protein: _proteinRegexp,
      NutritionLabelField.carbs: _carbsRegexp,
      NutritionLabelField.fat: _fatRegexp,
      NutritionLabelField.fiber: _fiberRegexp,
    }.entries) {
      for (final line in lines) {
        final keyword = entry.value.firstMatch(line);
        if (keyword == null || _subLineRegexp.hasMatch(line)) continue;
        final value = _numberPattern.firstMatch(line.substring(keyword.end));
        if (value == null) continue;
        final suffix = line.substring(keyword.end + value.end);
        if (RegExp(r'^\s*g\b', caseSensitive: false).hasMatch(suffix)) {
          fields.add(entry.key);
        }
        break;
      }
    }
    return fields;
  }

  static Set<NutritionLabelField> _upperBounds(List<String> lines) => {
        for (final entry in {
          NutritionLabelField.calories: _energyKeywordPattern,
          NutritionLabelField.protein: _proteinRegexp,
          NutritionLabelField.carbs: _carbsRegexp,
          NutritionLabelField.fat: _fatRegexp,
          NutritionLabelField.fiber: _fiberRegexp,
        }.entries)
          if (lines.any(
            (line) =>
                entry.value.hasMatch(line) &&
                RegExp(r'<\s*\d').hasMatch(line) &&
                !_subLineRegexp.hasMatch(line),
          ))
            entry.key,
      };

  static double? _extractMacro(List<String> lines, RegExp keywordPattern) {
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final keywordMatch = keywordPattern.firstMatch(line);
      if (keywordMatch == null) continue;

      // OCR frequently merges a main row and its indented sub-row, e.g.
      // "Carbohydrate 60g of which sugars 12g". Keep the main value when
      // the nutrient appears first, but reject genuine sub-rows such as
      // "of which sugars 12g" or "Saturated Fat 4g".
      final subLineMatch = _subLineRegexp.firstMatch(line);
      if (subLineMatch != null && subLineMatch.start < keywordMatch.start) {
        continue;
      }
      final valueEnd = subLineMatch?.start ?? line.length;
      final valueText = line.substring(keywordMatch.end, valueEnd);
      final match = _numberPattern.firstMatch(valueText);
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

  static NutritionUnit _extractNutritionUnit(String text) {
    final match = RegExp(
      r'(?:(?:per|pro|je|pour|por|w)\s*|[øØ⌀]\s*/?\s*|/\s*|\b)100\s*(g|ml)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (match?.group(1)?.toLowerCase() == 'ml') {
      return NutritionUnit.milliliter;
    }
    // Serving-only labels still need an explicit canonical basis. Prefer the
    // unit printed in the serving declaration when no per-100 heading exists.
    final servingVolume = RegExp(
      r'(?:serving|portion|servingsgröße|portionsgröße)[^\n]{0,60}\b\d+[\.,]?\d*\s*(g|ml)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (servingVolume?.group(1)?.toLowerCase() == 'ml' ||
        RegExp(r'\(\s*\d+[\.,]?\d*\s*ml\s*\)', caseSensitive: false)
            .hasMatch(text)) {
      return NutritionUnit.milliliter;
    }
    return NutritionUnit.gram;
  }

  static String? _extractServingName(List<String> lines) {
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (!_servingSizeLinePattern.hasMatch(line)) continue;

      final cleaned = line
          .replaceAll(
            RegExp(r'\(\s*\d+[\.,]?\d*\s*(?:g|ml)\s*\)', caseSensitive: false),
            '',
          )
          .replaceAll(
            RegExp(r'\b\d+[\.,]?\d*\s*(?:g|ml)\b', caseSensitive: false),
            '',
          )
          .replaceFirst(
            RegExp(
              r'^(?:serving\s*size|serving|portion|portionsgröße)\s*',
              caseSensitive: false,
            ),
            '',
          )
          .replaceFirst(RegExp(r'^\d+[\.,]?\d*\s*x?\s*'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.isNotEmpty && !_isMeasurementUnit(cleaned)) {
        return cleaned;
      }
    }
    return null;
  }

  static bool _isMeasurementUnit(String value) {
    return const <String>{'g', 'ml', 'gram', 'grams', 'gramm', 'kg', 'l'}
        .contains(value.toLowerCase());
  }

  static double _parseNumber(String raw) {
    final normalized = raw.replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  static String _normalizeOcrText(String text) {
    text = text
        .replaceAll(RegExp(r'kca[iI]', caseSensitive: false), 'kcal')
        .replaceAllMapped(
          RegExp(r'(\d)\s*([\.,])\s*(\d)'),
          (match) => '${match.group(1)}${match.group(2)}${match.group(3)}',
        );
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
