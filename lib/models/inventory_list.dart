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

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'is_active': isActive ? 1 : 0,
  };

  factory InventoryList.fromMap(Map<String, dynamic> map) => InventoryList(
    id: map['id'],
    name: map['name'] ?? '',
    description: map['description'],
    createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
    isActive: (map['is_active'] ?? 1) == 1,
  );

  InventoryList copyWith({
    int? id,
    String? name,
    String? description,
    bool? isActive,
  }) =>
      InventoryList(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        isActive: isActive ?? this.isActive,
      );
}
