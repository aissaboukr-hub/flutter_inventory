import 'package:flutter/material.dart';
import 'package:flutter_inventory/database/database_helper.dart';
import 'package:flutter_inventory/services/excel_service.dart';
import 'package:flutter_inventory/theme/app_theme.dart';
import 'package:flutter_inventory/l10n/app_localizations.dart';

class ImportExportScreen extends StatefulWidget {
  const ImportExportScreen({super.key});

  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> {
  bool _importing = false;
  int _productCount = 0;
  String? _lastImportInfo;

  @override
  void initState() {
    super.initState();
    _loadProductCount();
  }

  Future<void> _loadProductCount() async {
    final count = await DatabaseHelper.instance.getProductCount();
    if (mounted) setState(() => _productCount = count);
  }

  Future<void> _importFromFile() async {
    setState(() => _importing = true);
    try {
      final (products, result) = await ExcelService.importProductsFromFile();

      if (products.isEmpty && !result.hasErrors) {
        setState(() => _importing = false);
        return;
      }

      if (products.isNotEmpty) {
        // Confirmer l'import
        final confirmed = await _showImportPreview(products.length, result);
        if (confirmed == true) {
          final inserted = await DatabaseHelper.instance.insertProductsBatch(products);
          await _loadProductCount();
          setState(() {
            _lastImportInfo = '$inserted produits importés';
          });
          if (mounted) {
            _showSnack('$inserted produits importés avec succès', AppTheme.secondaryColor);
          }
        }
      }

      if (result.hasErrors && mounted) {
        _showErrorsDialog(result.errorMessages);
      }
    } catch (e) {
      if (mounted) _showSnack('Erreur: $e', AppTheme.errorColor);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<bool?> _showImportPreview(int count, ImportResult result) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.upload_file, color: AppTheme.primaryColor, size: 48),
        title: const Text('Confirmer l\'import'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow(Icons.check_circle, '$count produits valides', AppTheme.secondaryColor),
            if (result.hasErrors)
              _infoRow(Icons.warning, '${result.errors} lignes ignorées', AppTheme.warningColor),
            const SizedBox(height: 12),
            const Text('Les produits existants (même code-barres) seront mis à jour.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Importer')),
        ],
      ),
    );
  }

  void _showErrorsDialog(List<String> errors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Avertissements d\'import'),
        content: SizedBox(
          width: double.maxFinite,
          height: 200,
          child: ListView.builder(
            itemCount: errors.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• ${errors[i]}', style: const TextStyle(fontSize: 12)),
            ),
          ),
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _clearProducts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_forever, color: AppTheme.errorColor, size: 48),
        title: const Text('Vider le catalogue'),
        content: const Text('Supprimer tous les produits importés ?\nLes inventaires ne seront pas affectés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer tout'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseHelper.instance.clearProducts();
      await _loadProductCount();
      setState(() => _lastImportInfo = null);
      if (mounted) _showSnack('Catalogue vidé', AppTheme.warningColor);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(title: Text(l10n.importExport)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carte stats produits
            _buildStatsCard(),
            const SizedBox(height: 24),

            // Section Import
            _sectionTitle('Importer un catalogue de produits'),
            const SizedBox(height: 12),
            _buildImportCard(),
            const SizedBox(height: 24),

            // Section format attendu
            _sectionTitle('Format du fichier Excel'),
            const SizedBox(height: 12),
            _buildFormatCard(),
            const SizedBox(height: 24),

            // Section Google Sheets
            _sectionTitle('Google Sheets (optionnel)'),
            const SizedBox(height: 12),
            _buildGSheetsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, Color(0xFF3B82F6)]),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(Icons.inventory, color: Colors.white, size: 40),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Produits dans la base',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text('$_productCount produits',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          if (_lastImportInfo != null)
            Text(_lastImportInfo!, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      ],
    ),
  );

  Widget _buildImportCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Importer depuis un fichier .xlsx',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            'Sélectionnez un fichier Excel contenant vos produits. '
            'Les colonnes sont détectées automatiquement.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _importing ? null : _importFromFile,
                  icon: _importing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload_file),
                  label: Text(_importing ? 'Import en cours...' : 'Importer un fichier'),
                ),
              ),
              if (_productCount > 0) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                  onPressed: _clearProducts,
                  tooltip: 'Vider le catalogue',
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );

  Widget _buildFormatCard() => Card(
    color: const Color(0xFFF0F9FF),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
            SizedBox(width: 8),
            Text('Colonnes reconnues automatiquement',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
          ]),
          const SizedBox(height: 12),
          _formatRow('Code', 'code, référence, ref, sku'),
          _formatRow('Désignation', 'désignation, libellé, nom, article, produit'),
          _formatRow('Code-barres', 'barcode, ean, upc, code barre'),
          const SizedBox(height: 8),
          const Text(
            '✓ Les colonnes peuvent être dans n\'importe quel ordre\n'
            '✓ La première ligne est considérée comme en-tête\n'
            '✓ Les lignes vides sont ignorées',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    ),
  );

  Widget _buildGSheetsCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Image.network(
              'https://ssl.gstatic.com/docs/spreadsheets/favicon3.ico',
              width: 24,
              errorBuilder: (_, __, ___) => const Icon(Icons.table_chart, color: Colors.green),
            ),
            const SizedBox(width: 8),
            const Text('Google Sheets', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Config requise', style: TextStyle(fontSize: 10, color: AppTheme.warningColor)),
            ),
          ]),
          const SizedBox(height: 8),
          const Text(
            'Configurez votre compte de service Google dans les Paramètres pour activer la synchronisation avec Google Sheets.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Configurez Google Sheets dans les paramètres')),
              );
            },
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Configurer'),
          ),
        ],
      ),
    ),
  );

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)));

  Widget _formatRow(String col, String keywords) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(
        width: 110,
        child: Text(col, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      ),
      Expanded(child: Text(keywords, style: const TextStyle(fontSize: 11, color: Colors.grey))),
    ]),
  );

  Widget _infoRow(IconData icon, String text, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 8),
      Text(text),
    ]),
  );
}