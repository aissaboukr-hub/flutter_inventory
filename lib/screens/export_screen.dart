import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_inventory/models/inventory_entry.dart';
import 'package:flutter_inventory/models/inventory_list.dart';
import 'package:flutter_inventory/services/excel_service.dart';
import 'package:flutter_inventory/services/google_sheets_service.dart';
import 'package:flutter_inventory/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class ExportScreen extends StatefulWidget {
  final InventoryList inventoryList;
  final List<InventoryEntry> entries;
  final List<InventoryTotal> totals;

  const ExportScreen({
    super.key,
    required this.inventoryList,
    required this.entries,
    required this.totals,
  });

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _exporting = false;
  File? _exportedFile;

  Future<void> _generateExcel() async {
    setState(() => _exporting = true);
    try {
      final file = await ExcelService.exportInventory(
        inventoryList: widget.inventoryList,
        entries: widget.entries,
        totals: widget.totals,
      );
      setState(() => _exportedFile = file);
    } catch (e) {
      _showSnack('Erreur lors de la génération: $e', AppTheme.errorColor);
    } finally {
      setState(() => _exporting = false);
    }
  }

  Future<void> _shareFile() async {
    if (_exportedFile == null) await _generateExcel();
    if (_exportedFile != null) {
      await ExcelService.shareFile(_exportedFile!);
    }
  }

  Future<void> _openFile() async {
    if (_exportedFile == null) await _generateExcel();
    if (_exportedFile != null) {
      await OpenFilex.open(_exportedFile!.path);
    }
  }

  Future<void> _shareViaWhatsApp() async {
    if (_exportedFile == null) await _generateExcel();
    if (_exportedFile != null) {
      // Partage générique avec WhatsApp en option
      await ExcelService.shareFile(_exportedFile!);
    }
  }

  Future<void> _exportToGoogleSheets() async {
    if (!GoogleSheetsService.isInitialized) {
      _showSnack('Google Sheets non configuré. Allez dans les paramètres.', AppTheme.warningColor);
      return;
    }
    setState(() => _exporting = true);
    try {
      final success = await GoogleSheetsService.exportInventory(
        inventoryList: widget.inventoryList,
        entries: widget.entries,
        totals: widget.totals,
      );
      _showSnack(success ? 'Exporté vers Google Sheets !' : 'Échec export Google Sheets',
          success ? AppTheme.secondaryColor : AppTheme.errorColor);
    } catch (e) {
      _showSnack('Erreur: $e', AppTheme.errorColor);
    } finally {
      setState(() => _exporting = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(title: const Text('Exporter l\'inventaire')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 24),

            if (_exportedFile != null) _buildFileReadyCard(),
            if (_exportedFile != null) const SizedBox(height: 24),

            _sectionTitle('Générer le fichier Excel'),
            const SizedBox(height: 12),
            _buildGenerateCard(),
            const SizedBox(height: 24),

            _sectionTitle('Partager'),
            const SizedBox(height: 12),
            _buildShareOptions(),
            const SizedBox(height: 24),

            _sectionTitle('Google Sheets'),
            const SizedBox(height: 12),
            _buildGSheetsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [AppTheme.secondaryColor, Color(0xFF059669)]),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.inventoryList.name,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            _statItem(Icons.history, '${widget.entries.length}', 'Saisies'),
            const SizedBox(width: 24),
            _statItem(Icons.inventory, '${widget.totals.length}', 'Produits'),
            const SizedBox(width: 24),
            _statItem(
              Icons.calculate,
              widget.totals.fold(0.0, (s, t) => s + t.totalQuantity).toStringAsFixed(0),
              'Total Qté',
            ),
          ],
        ),
      ],
    ),
  );

  Widget _statItem(IconData icon, String value, String label) => Column(
    children: [
      Icon(icon, color: Colors.white70, size: 20),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ],
  );

  Widget _buildFileReadyCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.secondaryColor.withOpacity(0.1),
      border: Border.all(color: AppTheme.secondaryColor),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        const Icon(Icons.check_circle, color: AppTheme.secondaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Fichier prêt',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.secondaryColor)),
            Text(_exportedFile!.path.split('/').last,
                style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
          ]),
        ),
        TextButton(onPressed: _openFile, child: const Text('Ouvrir')),
      ],
    ),
  );

  Widget _buildGenerateCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Le fichier Excel contient deux feuilles :\n• Historique : toutes les saisies avec horodatage\n• Totaux : quantités cumulées par produit',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _exporting ? null : _generateExcel,
              icon: _exporting
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.table_view),
              label: Text(_exporting ? 'Génération...' : 'Générer le fichier Excel'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildShareOptions() => Card(
    child: Column(
      children: [
        _shareOption(
          icon: Icons.share,
          color: AppTheme.primaryColor,
          title: 'Partager',
          subtitle: 'Via e-mail, messages, etc.',
          onTap: _shareFile,
        ),
        const Divider(height: 1),
        _shareOption(
          icon: Icons.messenger_outline,
          color: const Color(0xFF25D366),
          title: 'WhatsApp',
          subtitle: 'Envoyer via WhatsApp',
          onTap: _shareViaWhatsApp,
        ),
        const Divider(height: 1),
        _shareOption(
          icon: Icons.save_alt,
          color: AppTheme.warningColor,
          title: 'Sauvegarder localement',
          subtitle: 'Ouvrir avec une autre application',
          onTap: _openFile,
        ),
      ],
    ),
  );

  Widget _shareOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );

  Widget _buildGSheetsCard() => Card(
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.table_chart, color: Colors.green),
      ),
      title: const Text('Exporter vers Google Sheets',
          style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        GoogleSheetsService.isInitialized
            ? 'Synchroniser avec Google Sheets'
            : 'Configuration requise dans les paramètres',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: GoogleSheetsService.isInitialized
          ? const Icon(Icons.chevron_right)
          : const Icon(Icons.lock_outline, color: Colors.grey),
      onTap: _exportToGoogleSheets,
    ),
  );

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)));
}
