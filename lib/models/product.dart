class Product {
  final int? id;
  final String code;
  final String designation;
  final String barcode;
  final DateTime createdAt;

  Product({
    this.id,
    required this.code,
    required this.designation,
    required this.barcode,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'designation': designation,
      'barcode': barcode,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      code: map['code'] ?? '',
      designation: map['designation'] ?? '',
      barcode: map['barcode'] ?? '',
      createdAt: _parseDate(map['created_at']),
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

  Product copyWith({
    int? id,
    String? code,
    String? designation,
    String? barcode,
  }) {
    return Product(
      id: id ?? this.id,
      code: code ?? this.code,
      designation: designation ?? this.designation,
      barcode: barcode ?? this.barcode,
      createdAt: createdAt,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, code: $code, designation: $designation, barcode: $barcode)';
  }
}
