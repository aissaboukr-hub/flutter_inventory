class InventoryList {
  final int? id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  InventoryList({
    this.id,
    required this.name,
    this.description,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isActive = true,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  factory InventoryList.fromMap(Map<String, dynamic> map) {
    return InventoryList(
      id: map['id'] as int?,
      name: map['name'] ?? '',
      description: map['description'],
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
      isActive: (map['is_active'] ?? 1) == 1,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return DateTime.now();
  }

  InventoryList copyWith({
    int? id,
    String? name,
    String? description,
    bool? isActive,
  }) {
    return InventoryList(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isActive: isActive ?? this.isActive,
    );
  }
}