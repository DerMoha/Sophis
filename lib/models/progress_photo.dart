enum PhotoCategory { front, side, back, other }

class ProgressPhoto {
  final String id;
  final String imagePath;
  final DateTime timestamp;
  final double? weightKg;
  final String? note;
  final PhotoCategory category;
  final DateTime createdAt;

  const ProgressPhoto({
    required this.id,
    required this.imagePath,
    required this.timestamp,
    this.weightKg,
    this.note,
    this.category = PhotoCategory.front,
    required this.createdAt,
  });

  ProgressPhoto copyWith({
    String? id,
    String? imagePath,
    DateTime? timestamp,
    double? weightKg,
    String? note,
    PhotoCategory? category,
    DateTime? createdAt,
  }) =>
      ProgressPhoto(
        id: id ?? this.id,
        imagePath: imagePath ?? this.imagePath,
        timestamp: timestamp ?? this.timestamp,
        weightKg: weightKg ?? this.weightKg,
        note: note ?? this.note,
        category: category ?? this.category,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePath': imagePath,
        'timestamp': timestamp.toIso8601String(),
        'weightKg': weightKg,
        'note': note,
        // Keep archive-v2 JSON backwards-compatible. Sync payloads use the
        // stable category key separately and do not depend on enum ordinals.
        'category': category.index,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ProgressPhoto.fromJson(Map<String, dynamic> json) => ProgressPhoto(
        id: json['id'] as String,
        imagePath: json['imagePath'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        note: json['note'] as String?,
        category: _photoCategoryFromJson(json['category']),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

PhotoCategory _photoCategoryFromJson(Object? value) {
  if (value is String) {
    return switch (value) {
      'front' => PhotoCategory.front,
      'side' => PhotoCategory.side,
      'back' => PhotoCategory.back,
      'other' => PhotoCategory.other,
      _ => PhotoCategory.front,
    };
  }
  if (value is num) {
    final index = value.toInt();
    if (index >= 0 && index < PhotoCategory.values.length) {
      return PhotoCategory.values[index];
    }
  }
  return PhotoCategory.front;
}
