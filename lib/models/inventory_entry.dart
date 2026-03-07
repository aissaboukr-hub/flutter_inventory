import 'package:flutter_inventory/models/product.dart';

class InventoryEntry {
  final int? id;
  final int inventoryListId;
  final int? productId;
  final String productCode;
  final String productDesignation;
  final String productBarcode;
  final double quantity;
  final DateTime scannedAt;
  final String? note;
  final bool isManual;

  InventoryEntry({
    this.id,
    required this.inventoryListId,
    this.productId,
    required this.productCode,
    required this.productDesignation,
    required this.productBarcode,
    required this.quantity,
    DateTime? scannedAt,
    this.note,
    this.isManual = false,
  }) : scannedAt = scannedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'inventory_list_id': inventoryListId,
    'product_id': productId,
    'product_code': productCode,
    'product_designation': productDesignation,
    'product_barcode': productBarcode,
    'quantity': quantity,
    'scanned_at': scannedAt.toIso8601String(),
    'note': note,
    'is_manual': isManual ? 1 : 0,
  };

  factory InventoryEntry.fromMap(Map<String, dynamic> map) => InventoryEntry(
    id: map['id'],
    inventoryListId: map['inventory_list_id'] ?? 0,
    productId: map['product_id'],
    productCode: map['product_code'] ?? '',
    productDesignation: map['product_designation'] ?? '',
    productBarcode: map['product_barcode'] ?? '',
    quantity: (map['quantity'] ?? 0).toDouble(),
    scannedAt: DateTime.tryParse(map['scanned_at'] ?? '') ?? DateTime.now(),
    note: map['note'],
    isManual: (map['is_manual'] ?? 0) == 1,
  );

  factory InventoryEntry.fromProduct(Product product, int listId, double qty) =>
      InventoryEntry(
        inventoryListId: listId,
        productId: product.id,
        productCode: product.code,
        productDesignation: product.designation,
        productBarcode: product.barcode,
        quantity: qty,
      );

  InventoryEntry copyWith({double? quantity, String? note}) => InventoryEntry(
    id: id,
    inventoryListId: inventoryListId,
    productId: productId,
    productCode: productCode,
    productDesignation: productDesignation,
    productBarcode: productBarcode,
    quantity: quantity ?? this.quantity,
    scannedAt: scannedAt,
    note: note ?? this.note,
    isManual: isManual,
  );
}

/// Totaux agrégés par produit
class InventoryTotal {
  final String productCode;
  final String productDesignation;
  final String productBarcode;
  final double totalQuantity;
  final int entryCount;

  InventoryTotal({
    required this.productCode,
    required this.productDesignation,
    required this.productBarcode,
    required this.totalQuantity,
    required this.entryCount,
  });
}
