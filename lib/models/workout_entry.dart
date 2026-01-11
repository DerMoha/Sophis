/// Manual workout entry for tracking burned calories
class WorkoutEntry {
  final String id;
  final double caloriesBurned;
  final DateTime timestamp;
  final String? note;

  const WorkoutEntry({
    required this.id,
    required this.caloriesBurned,
    required this.timestamp,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'caloriesBurned': caloriesBurned,
        'timestamp': timestamp.toIso8601String(),
        'note': note,
      };

  factory WorkoutEntry.fromJson(Map<String, dynamic> json) => WorkoutEntry(
        id: json['id'],
        caloriesBurned: (json['caloriesBurned'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp']),
        note: json['note'],
      );

  WorkoutEntry copyWith({
    String? id,
    double? caloriesBurned,
    DateTime? timestamp,
    String? note,
  }) =>
      WorkoutEntry(
        id: id ?? this.id,
        caloriesBurned: caloriesBurned ?? this.caloriesBurned,
        timestamp: timestamp ?? this.timestamp,
        note: note ?? this.note,
      );
}
