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

  /// ================================
  /// IMPORT PRODUITS
  /// ================================
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

      int codeIdx = 0;
      int designationIdx = 1;
      int barcodeIdx = 2;

      for (int r = 1; r < sheet.rows.length && r < _maxRows; r++) {
        final row = sheet.rows[r];
        if (row.isEmpty) continue;

        final code = row.length > codeIdx
            ? (row[codeIdx]?.value?.toString().trim() ?? '')
            : '';

        final designation = row.length > designationIdx
            ? (row[designationIdx]?.value?.toString().trim() ?? '')
            : '';

        final barcode = row.length > barcodeIdx
            ? (row[barcodeIdx]?.value?.toString().trim() ?? '')
            : '';

        if (designation.isEmpty) continue;

        products.add(Product(
          code: code.isEmpty ? 'AUTO_${r + 1}' : code,
          designation: designation,
          barcode: barcode,
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

  /// ================================
  /// EXPORT INVENTAIRE
  /// ================================
  static Future<File> exportInventory({
    required InventoryList inventoryList,
    required List<InventoryEntry> entries,
    required List<InventoryTotal> totals,
  }) async {
    final Excel excel = Excel.createExcel();

    final entriesList = List<InventoryEntry>.from(entries);
    final totalsList = List<InventoryTotal>.from(totals);

    _buildHistorySheet(excel, entriesList);
    _buildTotalsSheet(excel, totalsList, inventoryList);

    final dir = await getTemporaryDirectory();

    final timestamp =
        DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

    final fileName =
        'Inventaire_${_sanitize(inventoryList.name)}_$timestamp.xlsx';

    final filePath = '${dir.path}/$fileName';

    final bytes = excel.encode();

    if (bytes == null) {
      throw Exception('Erreur génération Excel');
    }

    final file = File(filePath);

    await file.writeAsBytes(bytes, flush: true);

    return file;
  }

  /// ================================
  /// FEUILLE HISTORIQUE
  /// ================================
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

    final headerStyle = CellStyle(bold: true);

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );

      cell.value = headers[i];
      cell.cellStyle = headerStyle;

      sheet.setColWidth(i, 25);
    }

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    for (int r = 0; r < entries.length; r++) {
      final e = entries[r];
      final row = r + 1;

      _setCell(sheet, 0, row, e.productCode);
      _setCell(sheet, 1, row, e.productDesignation);
      _setCell(sheet, 2, row, e.productBarcode);
      _setCell(sheet, 3, row, e.quantity);
      _setCell(sheet, 4, row, dateFormat.format(e.scannedAt));
      _setCell(sheet, 5, row, e.isManual ? 'Oui' : 'Non');
      _setCell(sheet, 6, row, e.note ?? '');
    }
  }

  /// ================================
  /// FEUILLE TOTAUX
  /// ================================
  static void _buildTotalsSheet(
      Excel excel,
      List<InventoryTotal> totals,
      InventoryList list) {

    final sheet = excel['Totaux'];

    final titleCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));

    titleCell.value = 'Inventaire : ${list.name}';
    titleCell.cellStyle = CellStyle(bold: true);

    final headers = [
      'Code',
      'Désignation',
      'Code-barres',
      'Quantité',
      'Nb saisies'
    ];

    final headerStyle = CellStyle(bold: true);

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2));

      cell.value = headers[i];
      cell.cellStyle = headerStyle;

      sheet.setColWidth(i, 25);
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

  /// ================================
  /// UTILITAIRE CELLULE
  /// ================================
  static void _setCell(Sheet sheet, int col, int row, dynamic value) {
    final cell =
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = value;
  }

  /// ================================
  /// PARTAGE
  /// ================================
  static Future<void> shareFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Export Inventaire',
    );
  }

  /// ================================
  /// SANITIZE NOM FICHIER
  /// ================================
  static String _sanitize(String name) {
    return name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_');
  }
}