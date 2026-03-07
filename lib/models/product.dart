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

  Map<String, dynamic> toMap() => {
    'id': id,
    'code': code,
    'designation': designation,
    'barcode': barcode,
    'created_at': createdAt.toIso8601String(),
  };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
    id: map['id'],
    code: map['code'] ?? '',
    designation: map['designation'] ?? '',
    barcode: map['barcode'] ?? '',
    createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
  );

  Product copyWith({
    int? id,
    String? code,
    String? designation,
    String? barcode,
  }) =>
      Product(
        id: id ?? this.id,
        code: code ?? this.code,
        designation: designation ?? this.designation,
        barcode: barcode ?? this.barcode,
        createdAt: createdAt,
      );

  @override
  String toString() => 'Product(id: $id, code: $code, designation: $designation, barcode: $barcode)';
}
