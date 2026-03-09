import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_inventory/models/product.dart';

typedef ProgressCallback = void Function(double progress);

class ExcelProgressImportService {

  static const int _maxRows = 200000;

  static Future<List<Product>> importProducts(ProgressCallback onProgress) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result == null || result.files.isEmpty) return [];

    final file = result.files.first;
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();

    final excel = Excel.decodeBytes(bytes);
    final products = <Product>[];

    for (final tableName in excel.tables.keys) {
      final sheet = excel.tables[tableName]!;

      if (sheet.rows.isEmpty) continue;

      final headerRow = sheet.rows.first;
      int codeIdx = 0;
      int designationIdx = 1;
      int barcodeIdx = 2;

      final totalRows = sheet.rows.length - 1;

      for (int r = 1; r < sheet.rows.length && r < _maxRows; r++) {
        final row = sheet.rows[r];
        if (row.isEmpty) continue;

        final code = row.length > codeIdx ? (row[codeIdx]?.value?.toString().trim() ?? '') : '';
        final designation = row.length > designationIdx ? (row[designationIdx]?.value?.toString().trim() ?? '') : '';
        final barcode = row.length > barcodeIdx ? (row[barcodeIdx]?.value?.toString().trim() ?? '') : '';

        if (designation.isEmpty) continue;

        products.add(Product(
          code: code.isEmpty ? 'AUTO_${r + 1}' : code,
          designation: designation,
          barcode: barcode.isEmpty ? 'BC_${code.isNotEmpty ? code : r + 1}' : barcode,
        ));

        // Mise à jour progression toutes les 100 lignes
        if (r % 100 == 0 || r == totalRows) {
          onProgress(r / totalRows);
        }
      }

      break;
    }

    onProgress(1.0); // terminé
    return products;
  }
}