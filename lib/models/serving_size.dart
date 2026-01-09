/// Represents a serving size option for a food item
class ServingSize {
  final String name;
  final double grams;
  final double multiplier;
  final bool isCustom;

  const ServingSize({
    required this.name,
    required this.grams,
    this.multiplier = 1.0,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'grams': grams,
        'multiplier': multiplier,
        'isCustom': isCustom,
      };

  factory ServingSize.fromJson(Map<String, dynamic> json) => ServingSize(
        name: json['name'] as String,
        grams: (json['grams'] as num).toDouble(),
        multiplier: (json['multiplier'] as num?)?.toDouble() ?? 1.0,
        isCustom: json['isCustom'] as bool? ?? false,
      );

  /// Generate fractional serving options from a base serving
  static List<ServingSize> generateFractions(String baseName, double baseGrams) {
    final multipliers = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0];
    final fractionNames = {
      0.25: '1/4',
      0.5: '1/2',
      0.75: '3/4',
      1.0: '1',
      1.5: '1.5',
      2.0: '2',
    };

    return multipliers.map((m) {
      final displayName = '${fractionNames[m]} $baseName';
      return ServingSize(
        name: displayName,
        grams: baseGrams * m,
        multiplier: m,
      );
    }).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServingSize &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          grams == other.grams;

  @override
  int get hashCode => name.hashCode ^ grams.hashCode;
}
