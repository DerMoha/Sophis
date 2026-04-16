class ExtractedIngredient {
  final String name;
  final double amount;
  final String unit;
  final String category;

  ExtractedIngredient({
    required this.name,
    required this.amount,
    required this.unit,
    required this.category,
  });

  String get displayAmount {
    if (amount == amount.toInt()) {
      return '${amount.toInt()} $unit';
    }
    return '${amount.toStringAsFixed(1)} $unit';
  }
}
