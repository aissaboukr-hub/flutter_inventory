```dart
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_inventory/models/product.dart';
import 'package:flutter_inventory/models/inventory_entry.dart';
import 'package:flutter_inventory/models/inventory_list.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class ImportResult {
  final int imported;
  final int errors;
  final List<String> errorMessages;

  ImportResult({
    required this.imported,
    required this.errors,
    required this.errorMessages,
  });

  bool get hasErrors => errors > 0;
  bool get success => imported > 0;
}

class ExcelService {
  static const _maxRows = 100000;

  /// IMPORT PRODUITS
  static Future<(List<Product>, ImportResult)> importProductsFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result == null || result.files.isEmpty) {
      return (<Product>[],
          ImportResult(imported: 0, errors: 0, errorMessages: []));
    }

    final file = result.files.first;
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();

    return _parseExcelBytes(bytes);
  }

  static Future<(List<Product>, ImportResult)> _parseExcelBytes(
      List<int> bytes) async {
    final excel = Excel.decodeBytes(bytes);

    final products = <Product>[];
    final errors = <String>[];
    int errorCount = 0;

    for (final tableName in excel.tables.keys) {
      final sheet = excel.tables[tableName]!;

      if (sheet.rows.isEmpty) continue;

      final headerRow = sheet.rows.first;

      int codeIdx = -1;
      int designationIdx = -1;
      int barcodeIdx = -1;

      for (int i = 0; i < headerRow.length; i++) {
        final header =
            (headerRow[i]?.value?.toString() ?? '').toLowerCase().trim();

        if (_matchesCode(header)) codeIdx = i;
        if (_matchesDesignation(header)) designationIdx = i;
        if (_matchesBarcode(header)) barcodeIdx = i;
      }

      if (codeIdx == -1 && designationIdx == -1 && barcodeIdx == -1) {
        codeIdx = 0;
        designationIdx = 1;
        barcodeIdx = 2;
      }

      if (designationIdx == -1) {
        errors.add(
            'Colonne "Désignation" introuvable dans la feuille "$tableName"');
        errorCount++;
        continue;
      }

      for (int r = 1; r < sheet.rows.length && r < _maxRows; r++) {
        final row = sheet.rows[r];

        if (row.isEmpty) continue;

        final code =
            codeIdx >= 0 ? (row[codeIdx]?.value?.toString().trim() ?? '') : '';

        final designation = designationIdx >= 0
            ? (row[designationIdx]?.value?.toString().trim() ?? '')
            : '';

        final barcode = barcodeIdx >= 0
            ? (row[barcodeIdx]?.value?.toString().trim() ?? '')
            : '';

        if (designation.isEmpty) continue;

        final validationError =
            _validateProductRow(r + 1, code, designation, barcode);

        if (validationError != null) {
          errors.add(validationError);
          errorCount++;
          continue;
        }

        products.add(Product(
          code: code.isEmpty ? 'AUTO_${r + 1}' : code,
          designation: designation,
          barcode: barcode.isEmpty
              ? 'BC_${code.isNotEmpty ? code : r + 1}'
              : barcode,
        ));
      }

      break;
    }

    return (
      products,
      ImportResult(
        imported: products.length,
        errors: errorCount,
        errorMessages: errors,
      )
    );
  }

  static bool _matchesCode(String h) =>
      h.contains('code') && !h.contains('bar');

  static bool _matchesDesignation(String h) =>
      h.contains('design') ||
      h.contains('libelle') ||
      h.contains('nom') ||
      h.contains('produit');

  static bool _matchesBarcode(String h) =>
      h.contains('bar') || h.contains('ean') || h.contains('qr');

  static String? _validateProductRow(
      int row, String code, String designation, String barcode) {
    if (designation.length > 255) {
      return 'Ligne $row: désignation trop longue';
    }
    return null;
  }

  /// EXPORT INVENTAIRE
  static Future<File> exportInventory({
    required InventoryList inventoryList,
    required List<InventoryEntry> entries,
    required List<InventoryTotal> totals,
  }) async {
    final Excel excel = Excel.createExcel();

    _buildHistorySheet(excel, entries);
    _buildTotalsSheet(excel, totals, inventoryList);

    excel.delete('Sheet1');

    final dir = await getTemporaryDirectory();

    final timestamp =
        DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

    final fileName =
        'Inventaire_${_sanitize(inventoryList.name)}_$timestamp.xlsx';

    final filePath = '${dir.path}/$fileName';

    final fileBytes = excel.encode();

    if (fileBytes == null) {
      throw Exception('Erreur génération Excel');
    }

    final file = File(filePath);

    await file.writeAsBytes(fileBytes);

    return file;
  }

  static void _buildHistorySheet(
      Excel excel, List<InventoryEntry> entries) {
    final sheet = excel['Historique'];

    final headers = [
      'Code',
      'Désignation',
      'Code-barres',
      'Quantité',
      'Date',
      'Manuel',
      'Note'
    ];

    for (int i = 0; i < headers.length; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .value = headers[i];
    }

    for (int r = 0; r < entries.length; r++) {
      final e = entries[r];

      final row = r + 1;

      _setCell(sheet, 0, row, e.productCode);
      _setCell(sheet, 1, row, e.productDesignation);
      _setCell(sheet, 2, row, e.productBarcode);
      _setCell(sheet, 3, row, e.quantity);

      _setCell(
        sheet,
        4,
        row,
        DateFormat('dd/MM/yyyy HH:mm').format(e.scannedAt),
      );

      _setCell(sheet, 5, row, e.isManual ? 'Oui' : 'Non');

      _setCell(sheet, 6, row, e.note ?? '');
    }
  }

  static void _buildTotalsSheet(
      Excel excel,
      List<InventoryTotal> totals,
      InventoryList list) {
    final sheet = excel['Totaux'];

    _setCell(sheet, 0, 0, 'Inventaire : ${list.name}');

    final headers = [
      'Code',
      'Désignation',
      'Code-barres',
      'Quantité',
      'Nb saisies'
    ];

    for (int i = 0; i < headers.length; i++) {
      _setCell(sheet, i, 2, headers[i]);
    }

    for (int r = 0; r < totals.length; r++) {
      final t = totals[r];
      final row = r + 3;

      _setCell(sheet, 0, row, t.productCode);
      _setCell(sheet, 1, row, t.productDesignation);
      _setCell(sheet, 2, row, t.productBarcode);
      _setCell(sheet, 3, row, t.totalQuantity);
      _setCell(sheet, 4, row, t.entryCount);
    }
  }

  static void _setCell(Sheet sheet, int col, int row, dynamic value) {
    final cell =
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));

    cell.value = value;
  }

  static Future<void> shareFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Export Inventaire',
    );
  }

  static String _sanitize(String name) {
    return name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_');
  }
}
```
