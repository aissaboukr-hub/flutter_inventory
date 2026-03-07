import 'package:gsheets/gsheets.dart';
import 'package:flutter_inventory/models/product.dart';
import 'package:flutter_inventory/models/inventory_entry.dart';
import 'package:flutter_inventory/models/inventory_list.dart';
import 'package:intl/intl.dart';

class GoogleSheetsConfig {
  final String credentials;
  final String spreadsheetId;

  const GoogleSheetsConfig({
    required this.credentials,
    required this.spreadsheetId,
  });
}

class GoogleSheetsService {
  static GSheets? _gsheets;
  static Spreadsheet? _spreadsheet;

  static Future<bool> init(GoogleSheetsConfig config) async {
    try {
      _gsheets = GSheets(config.credentials);
      _spreadsheet = await _gsheets!.spreadsheet(config.spreadsheetId);
      return true;
    } catch (e) {
      return false;
    }
  }

  static bool get isInitialized => _gsheets != null && _spreadsheet != null;

  /// Importer des produits depuis Google Sheets
  static Future<List<Product>> importProducts({String sheetName = 'Produits'}) async {
    if (_spreadsheet == null) throw Exception('Google Sheets non initialisé');

    final sheet = _spreadsheet!.worksheetByTitle(sheetName) ??
        await _spreadsheet!.addWorksheet(sheetName);

    final rows = await sheet.values.allRows(fromRow: 2);
    final products = <Product>[];

    for (final row in rows) {
      if (row.isEmpty || (row.length > 1 && row[1].isEmpty)) continue;
      products.add(Product(
        code: row.isNotEmpty ? row[0] : '',
        designation: row.length > 1 ? row[1] : '',
        barcode: row.length > 2 ? row[2] : '',
      ));
    }

    return products;
  }

  /// Exporter un inventaire vers Google Sheets
  static Future<bool> exportInventory({
    required InventoryList inventoryList,
    required List<InventoryEntry> entries,
    required List<InventoryTotal> totals,
  }) async {
    if (_spreadsheet == null) return false;

    try {
      final timestamp = DateFormat('dd-MM-yy_HHmm').format(DateTime.now());
      final sheetName = '${inventoryList.name}_$timestamp'.substring(
          0, '${inventoryList.name}_$timestamp'.length.clamp(0, 50));

      // Créer ou obtenir la feuille
      var sheet = _spreadsheet!.worksheetByTitle(sheetName);
      sheet ??= await _spreadsheet!.addWorksheet(sheetName);

      // En-têtes
      await sheet.values.insertRow(1, ['Code', 'Désignation', 'Code-barres', 'Quantité Totale', 'Nb Saisies']);

      // Totaux
      for (int i = 0; i < totals.length; i++) {
        final t = totals[i];
        await sheet.values.insertRow(i + 2, [
          t.productCode,
          t.productDesignation,
          t.productBarcode,
          t.totalQuantity.toString(),
          t.entryCount.toString(),
        ]);
      }

      // Feuille historique
      var histSheet = _spreadsheet!.worksheetByTitle('${sheetName}_Hist');
      histSheet ??= await _spreadsheet!.addWorksheet('${sheetName}_Hist');

      await histSheet.values.insertRow(1, ['Code', 'Désignation', 'Code-barres', 'Quantité', 'Date']);
      for (int i = 0; i < entries.length; i++) {
        final e = entries[i];
        await histSheet.values.insertRow(i + 2, [
          e.productCode,
          e.productDesignation,
          e.productBarcode,
          e.quantity.toString(),
          DateFormat('dd/MM/yyyy HH:mm').format(e.scannedAt),
        ]);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  static void dispose() {
    _gsheets = null;
    _spreadsheet = null;
  }
}
