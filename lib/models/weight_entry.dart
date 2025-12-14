/// Weight tracking entry
class WeightEntry {
  final String id;
  final double weightKg;
  final DateTime timestamp;
  final String? note;

  const WeightEntry({
    required this.id,
    required this.weightKg,
    required this.timestamp,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'weightKg': weightKg,
    'timestamp': timestamp.toIso8601String(),
    'note': note,
  };

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
    id: json['id'],
    weightKg: (json['weightKg'] as num).toDouble(),
    timestamp: DateTime.parse(json['timestamp']),
    note: json['note'],
  );
}
