class SupplementLogEntry {
  final String id;
  final String supplementId;
  final DateTime timestamp;

  const SupplementLogEntry({
    required this.id,
    required this.supplementId,
    required this.timestamp,
  });

  SupplementLogEntry copyWith({
    String? id,
    String? supplementId,
    DateTime? timestamp,
  }) {
    return SupplementLogEntry(
      id: id ?? this.id,
      supplementId: supplementId ?? this.supplementId,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplementId': supplementId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SupplementLogEntry.fromJson(Map<String, dynamic> json) {
    return SupplementLogEntry(
      id: json['id'] as String,
      supplementId: json['supplementId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
