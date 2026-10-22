class NutritionOcrToken {
  final String text;
  final double centerX;
  final double? centerY;

  const NutritionOcrToken({
    required this.text,
    required this.centerX,
    this.centerY,
  });
}

class NutritionOcrLine {
  final String text;
  final double top;
  final double? height;
  final double? left;
  final double? right;
  final List<NutritionOcrToken> tokens;

  const NutritionOcrLine({
    required this.text,
    required this.top,
    this.height,
    this.left,
    this.right,
    required this.tokens,
  });
}
