/// User-defined portion preset for a specific product
class CustomPortion {
  final String id;
  final String productKey; // barcode or normalized product name
  final String name;
  final double grams;
  final DateTime createdAt;

  const CustomPortion({
    required this.id,
    required this.productKey,
    required this.name,
    required this.grams,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'productKey': productKey,
        'name': name,
        'grams': grams,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CustomPortion.fromJson(Map<String, dynamic> json) => CustomPortion(
        id: json['id'] as String,
        productKey: json['productKey'] as String,
        name: json['name'] as String,
        grams: (json['grams'] as num).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  /// Create a unique product key from barcode or name
  static String createProductKey({String? barcode, required String name}) {
    if (barcode != null && barcode.isNotEmpty) {
      return 'barcode:$barcode';
    }
    return 'name:${name.toLowerCase().trim()}';
  }
}
