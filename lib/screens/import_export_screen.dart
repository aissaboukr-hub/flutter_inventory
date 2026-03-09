import 'package:flutter/material.dart';
import 'package:flutter_inventory/database/database_helper.dart';
import 'package:flutter_inventory/services/excel_service.dart';
import 'package:flutter_inventory/theme/app_theme.dart';
import 'package:flutter_inventory/l10n/app_localizations.dart';
import '../services/excel_progress_service.dart';

class ImportExportScreen extends StatefulWidget {
  const ImportExportScreen({super.key});

  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> {
  bool _importing = false;
  double _progress = 0;
  int _productCount = 0;
  int _importedCount = 0;
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
    setState(() {
      _importing = true;
      _progress = 0;
    });

    try {
      final (products, result) = await ExcelService.importProductsFromFile();

      if (products.isEmpty && !result.hasErrors) return;

      if (products.isNotEmpty) {
        final confirmed = await _showImportPreview(products.length, result);
        if (confirmed == true) {
          final inserted = await DatabaseHelper.instance.insertProductsBatch(products);
          await _loadProductCount();
          setState(() {
            _importedCount = inserted;
            _lastImportInfo = '$inserted produits importés';
          });
          if (mounted) _showSnack('$inserted produits importés avec succès', AppTheme.secondaryColor);
        }
      }

      if (result.hasErrors && mounted) _showErrorsDialog(result.errorMessages);
    } catch (e) {
      if (mounted) _showSnack('Erreur: $e', AppTheme.errorColor);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _importFromFileWithProgress() async {
    setState(() {
      _importing = true;
      _progress = 0;
    });

    try {
      final products = await ExcelProgressImportService.importProducts((progress) {
        if (mounted) setState(() => _progress = progress);
      });

      if (products.isEmpty) return;

      final confirmed = await _showImportPreviewSimple(products.length);
      if (confirmed == true) {
        final inserted = await DatabaseHelper.instance.insertProductsBatch(products);
        await _loadProductCount();
        setState(() {
          _importedCount = inserted;
          _lastImportInfo = '$inserted produits importés';
        });
        _showSnack('$inserted produits importés avec succès', AppTheme.secondaryColor);
      }
    } catch (e) {
      _showSnack('Erreur import: $e', AppTheme.errorColor);
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

  Future<bool?> _showImportPreviewSimple(int count) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.upload_file, color: AppTheme.primaryColor, size: 48),
        title: const Text('Confirmer l\'import'),
        content: Text('$count produits valides prêts à être importés.'),
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

  Widget _infoRow(IconData icon, String text, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(text),
        ]),
      );

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
            _sectionTitle('Importer un catalogue de produits'),
            const SizedBox(height: 12),
            _buildImportCard(),
            if (_importing) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress, minHeight: 10),
              const SizedBox(height: 4),
              Text('${(_progress * 100).toStringAsFixed(0)} %',
                  style: const TextStyle(fontSize: 12)),
            ],
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
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              if (_lastImportInfo != null)
                Text(_lastImportInfo!,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11)),
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
                      onPressed: _importing ? null : _importFromFileWithProgress,
                      icon: _importing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.upload_file),
                      label:
                          Text(_importing ? 'Import en cours...' : 'Importer un fichier'),
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

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)));
}