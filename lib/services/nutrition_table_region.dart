import 'dart:math' as math;

import 'package:sophis/services/nutrition_ocr_document.dart';

/// A region inferred from a cluster of short nutrient row labels, not from
/// the first occurrence of “100 ml” somewhere on the package.
class NutritionTableRegion {
  final double left;
  final double top;
  final double right;
  final double bottom;
  final List<NutritionOcrLine> lines;

  const NutritionTableRegion({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.lines,
  });

  static final _row = RegExp(
    r'^[|\s]*(?:energ\w*|eneroi\w*|brennwert|calories|fett\b|fat\b|kohlen\w*|carbo\w*|carbs\b|e[il]wei\w*|protein\w*|ballast\w*|fib(?:er|re)\w*|salz\b|salt\b)',
    caseSensitive: false,
  );

  static bool isRow(String text) => text.length < 65 && _row.hasMatch(text);

  static NutritionTableRegion? locate(List<NutritionOcrLine> input) {
    final rows = input.where((line) => isRow(line.text)).toList()
      ..sort((a, b) => a.top.compareTo(b.top));
    if (rows.length < 3) return null;
    final heights = rows.map((r) => r.height ?? 20).toList()..sort();
    final h = heights[heights.length ~/ 2];
    // Separate distant tables or text panels. Keep the densest nutrient block.
    final groups = <List<NutritionOcrLine>>[];
    for (final row in rows) {
      if (groups.isEmpty || row.top - groups.last.last.top > h * 6) {
        groups.add([row]);
      } else {
        groups.last.add(row);
      }
    }
    groups.sort((a, b) => b.length.compareTo(a.length));
    final group = groups.first;
    if (group.length < 3) return null;
    final rowTop = group.first.top;
    final rowBottom = group.last.top + (group.last.height ?? h);
    var top = rowTop - h * 2.5;
    final bottom = rowBottom + h * 1.5;
    final headings = input.where(
      (line) =>
          RegExp(r'100\s*(?:g|ml)\b', caseSensitive: false)
              .hasMatch(line.text) &&
          line.top >= rowTop - h * 5 &&
          line.top <= rowTop + h,
    );
    if (headings.isNotEmpty) {
      top = headings.map((r) => r.top).reduce(math.min) - h * 0.5;
    }
    final labelLeft = group
        .map(
          (r) =>
              r.left ??
              r.tokens
                  .map((t) => t.centerX)
                  .fold<double>(double.infinity, math.min),
        )
        .reduce(math.min);
    if (!labelLeft.isFinite) return null;
    final selected = input
        .where(
          (line) =>
              line.top >= top &&
              line.top < bottom &&
              (line.right ??
                      line.tokens
                          .map((t) => t.centerX)
                          .fold<double>(0.0, math.max)) >=
                  labelLeft,
        )
        .toList();
    final right = selected
        .map<double>(
          (r) =>
              r.right ??
              r.tokens.map((t) => t.centerX).fold<double>(0.0, math.max),
        )
        .fold<double>(0.0, math.max);
    if (right <= labelLeft) return null;
    return NutritionTableRegion(
      left: math.max(0, labelLeft - h),
      top: math.max(0, top),
      right: right + h,
      bottom: bottom,
      lines: selected,
    );
  }
}
