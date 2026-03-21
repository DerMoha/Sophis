/// Weight tracking entry
class WeightEntry {
  final String id;
  final double weightKg;
  final DateTime timestamp;
  final String? note;
  final String source; // 'manual' | 'health'

  const WeightEntry({
    required this.id,
    required this.weightKg,
    required this.timestamp,
    this.note,
    this.source = 'manual',
  });

  WeightEntry copyWith({
    String? id,
    double? weightKg,
    DateTime? timestamp,
    String? note,
    String? source,
  }) => WeightEntry(
    id: id ?? this.id,
    weightKg: weightKg ?? this.weightKg,
    timestamp: timestamp ?? this.timestamp,
    note: note ?? this.note,
    source: source ?? this.source,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'weightKg': weightKg,
    'timestamp': timestamp.toIso8601String(),
    'note': note,
    'source': source,
  };

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
    id: json['id'],
    weightKg: (json['weightKg'] as num).toDouble(),
    timestamp: DateTime.parse(json['timestamp']),
    note: json['note'],
    source: json['source'] as String? ?? 'manual',
  );
}
