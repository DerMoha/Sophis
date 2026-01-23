class Supplement {
  final String id;
  final String name;
  final String? reminderTime;  // "HH:mm" format
  final bool enabled;
  final int sortOrder;
  final DateTime createdAt;

  const Supplement({
    required this.id,
    required this.name,
    this.reminderTime,
    this.enabled = true,
    this.sortOrder = 0,
    required this.createdAt,
  });

  Supplement copyWith({
    String? id,
    String? name,
    String? reminderTime,
    bool? enabled,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return Supplement(
      id: id ?? this.id,
      name: name ?? this.name,
      reminderTime: reminderTime ?? this.reminderTime,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'reminderTime': reminderTime,
      'enabled': enabled,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Supplement.fromJson(Map<String, dynamic> json) {
    return Supplement(
      id: json['id'] as String,
      name: json['name'] as String,
      reminderTime: json['reminderTime'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      sortOrder: json['sortOrder'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
