/// Water consumption entry
class WaterEntry {
  final String id;
  final double amountMl;
  final DateTime timestamp;

  const WaterEntry({
    required this.id,
    required this.amountMl,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'amountMl': amountMl,
    'timestamp': timestamp.toIso8601String(),
  };

  factory WaterEntry.fromJson(Map<String, dynamic> json) => WaterEntry(
    id: json['id'],
    amountMl: (json['amountMl'] as num).toDouble(),
    timestamp: DateTime.parse(json['timestamp']),
  );
}
