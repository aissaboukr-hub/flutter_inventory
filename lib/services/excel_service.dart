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

  ImportResult({required this.imported, required this.errors, required this.errorMessages});

  bool get hasErrors => errors > 0;
  bool get success => imported > 0;
}

class ExcelService {
  static const _maxRows = 100000;

  /// Importer des produits depuis un fichier .xlsx
  static Future<(List<Product>, ImportResult)> importProductsFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result == null || result.files.isEmpty) {
      return (<Product>[], ImportResult(imported: 0, errors: 0, errorMessages: []));
    }

    final file = result.files.first;
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    return _parseExcelBytes(bytes);
  }

  static Future<(List<Product>, ImportResult)> _parseExcelBytes(List<int> bytes) async {
    final excel = Excel.decodeBytes(bytes);
    final products = <Product>[];
    final errors = <String>[];
    int errorCount = 0;

    for (final tableName in excel.tables.keys) {
      final sheet = excel.tables[tableName]!;
      if (sheet.rows.isEmpty) continue;

      // Détection automatique des colonnes
      final headerRow = sheet.rows.first;
      int codeIdx = -1, designationIdx = -1, barcodeIdx = -1;

      for (int i = 0; i < headerRow.length; i++) {
        final header = (headerRow[i]?.value?.toString() ?? '').toLowerCase().trim();
        if (_matchesCode(header)) codeIdx = i;
        if (_matchesDesignation(header)) designationIdx = i;
        if (_matchesBarcode(header)) barcodeIdx = i;
      }

      // Si pas d'en-tête, essayer colonnes par défaut
      if (codeIdx == -1 && designationIdx == -1 && barcodeIdx == -1) {
        codeIdx = 0; designationIdx = 1; barcodeIdx = 2;
      }

      if (designationIdx == -1) {
        errors.add('Colonne "Désignation" introuvable dans la feuille "$tableName"');
        errorCount++;
        continue;
      }

      final startRow = headerRow.any((c) => _isHeaderCell(c?.value?.toString() ?? '')) ? 1 : 0;

      for (int r = startRow; r < sheet.rows.length && r < _maxRows; r++) {
        final row = sheet.rows[r];
        if (row.isEmpty) continue;

        final code = codeIdx >= 0 ? (row[codeIdx]?.value?.toString().trim() ?? '') : '';
        final designation = designationIdx >= 0 ? (row[designationIdx]?.value?.toString().trim() ?? '') : '';
        final barcode = barcodeIdx >= 0 ? (row[barcodeIdx]?.value?.toString().trim() ?? '') : '';

        if (designation.isEmpty) continue;

        // Validation
        final validationError = _validateProductRow(r + 1, code, designation, barcode);
        if (validationError != null) {
          errors.add(validationError);
          errorCount++;
          continue;
        }

        products.add(Product(
          code: code.isEmpty ? 'AUTO_${r + 1}' : code,
          designation: designation,
          barcode: barcode.isEmpty ? 'BC_${code.isNotEmpty ? code : r + 1}' : barcode,
        ));
      }
      break; // Première feuille uniquement par défaut
    }

    return (products, ImportResult(imported: products.length, errors: errorCount, errorMessages: errors));
  }

  static bool _matchesCode(String h) =>
      h.contains('code') && !h.contains('bar') && !h.contains('barre');
  static bool _matchesDesignation(String h) =>
      h.contains('désign') || h.contains('design') || h.contains('libellé') ||
      h.contains('libelle') || h.contains('nom') || h.contains('article') ||
      h.contains('produit') || h.contains('description');
  static bool _matchesBarcode(String h) =>
      h.contains('bar') || h.contains('ean') || h.contains('upc') || h.contains('qr');
  static bool _isHeaderCell(String v) =>
      _matchesCode(v.toLowerCase()) || _matchesDesignation(v.toLowerCase()) ||
      _matchesBarcode(v.toLowerCase());

  static String? _validateProductRow(int row, String code, String designation, String barcode) {
    if (designation.length > 255) return 'Ligne $row: désignation trop longue (>255)';
    if (code.length > 100) return 'Ligne $row: code produit trop long (>100)';
    if (barcode.length > 100) return 'Ligne $row: code-barres trop long (>100)';
    return null;
  }

  // ─── EXPORT ───────────────────────────────────────────────────────────────

  static Future<File> exportInventory({
    required InventoryList inventoryList,
    required List<InventoryEntry> entries,
    required List<InventoryTotal> totals,
  }) async {
    final excel = Excel.createExcel();

    // Feuille Historique
    _buildHistorySheet(excel, entries);
    // Feuille Totaux
    _buildTotalsSheet(excel, totals, inventoryList);

    // Supprimer la feuille par défaut
    excel.delete('Sheet1');

    final dir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'Inventaire_${_sanitize(inventoryList.name)}_$timestamp.xlsx';
    final filePath = '${dir.path}/$fileName';

    final fileBytes = excel.encode();
    if (fileBytes == null) throw Exception('Erreur lors de la génération du fichier');

    final file = File(filePath);
    await file.writeAsBytes(fileBytes);
    return file;
  }

  static void _buildHistorySheet(Excel excel, List<InventoryEntry> entries) {
    final sheet = excel['Historique'];

    // En-têtes
    final headers = ['Code', 'Désignation', 'Code-barres', 'Quantité', 'Date/Heure', 'Saisie manuelle', 'Note'];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#2563EB'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    // Données
    for (int r = 0; r < entries.length; r++) {
      final e = entries[r];
      final row = r + 1;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(e.productCode);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(e.productDesignation);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = TextCellValue(e.productBarcode);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = DoubleCellValue(e.quantity);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
          TextCellValue(DateFormat('dd/MM/yyyy HH:mm:ss').format(e.scannedAt));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value =
          TextCellValue(e.isManual ? 'Oui' : 'Non');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value =
          TextCellValue(e.note ?? '');
    }

    // Largeurs colonnes
    sheet.setColumnWidth(0, 15);
    sheet.setColumnWidth(1, 40);
    sheet.setColumnWidth(2, 20);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 20);
    sheet.setColumnWidth(5, 18);
    sheet.setColumnWidth(6, 30);
  }

  static void _buildTotalsSheet(Excel excel, List<InventoryTotal> totals, InventoryList list) {
    final sheet = excel['Totaux'];

    // Titre
    final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue('Inventaire: ${list.name}');
    titleCell.cellStyle = CellStyle(bold: true, fontSize: 14);

    final dateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
    dateCell.value = TextCellValue('Généré le: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}');

    // En-têtes
    final headers = ['Code', 'Désignation', 'Code-barres', 'Quantité Totale', 'Nb Saisies'];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#10B981'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    // Données
    for (int r = 0; r < totals.length; r++) {
      final t = totals[r];
      final row = r + 4;
      final bg = r % 2 == 0 ? ExcelColor.fromHexString('#F8FAFC') : ExcelColor.fromHexString('#FFFFFF');

      _setCellWithStyle(sheet, 0, row, TextCellValue(t.productCode), bg);
      _setCellWithStyle(sheet, 1, row, TextCellValue(t.productDesignation), bg);
      _setCellWithStyle(sheet, 2, row, TextCellValue(t.productBarcode), bg);
      _setCellWithStyle(sheet, 3, row, DoubleCellValue(t.totalQuantity), bg);
      _setCellWithStyle(sheet, 4, row, IntCellValue(t.entryCount), bg);
    }

    // Total général
    final totalRow = totals.length + 4;
    final sumCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: totalRow));
    sumCell.value = TextCellValue('TOTAL GÉNÉRAL');
    sumCell.cellStyle = CellStyle(bold: true);

    final sumQtyCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: totalRow));
    sumQtyCell.value = DoubleCellValue(totals.fold(0.0, (s, t) => s + t.totalQuantity));
    sumQtyCell.cellStyle = CellStyle(bold: true);

    sheet.setColumnWidth(0, 15);
    sheet.setColumnWidth(1, 40);
    sheet.setColumnWidth(2, 20);
    sheet.setColumnWidth(3, 18);
    sheet.setColumnWidth(4, 15);
  }

  static void _setCellWithStyle(Excel sheet, int col, int row, CellValue value, ExcelColor bg) {
    // ignore: unused_local_variable
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = value;
  }

  static Future<void> shareFile(File file) async {
    await Share.shareXFiles([XFile(file.path)], subject: 'Export Inventaire');
  }

  static String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
}
