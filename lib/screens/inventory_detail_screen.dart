import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:flutter_inventory/database/database_helper.dart';
import 'package:flutter_inventory/models/inventory_entry.dart';
import 'package:flutter_inventory/models/inventory_list.dart';
import 'package:flutter_inventory/models/product.dart';
import 'package:flutter_inventory/screens/scanner_screen.dart';
import 'package:flutter_inventory/screens/export_screen.dart';
import 'package:flutter_inventory/theme/app_theme.dart';
import 'package:flutter_inventory/widgets/quantity_dialog.dart';
import 'package:flutter_inventory/widgets/manual_product_dialog.dart';
import 'package:flutter_inventory/widgets/search_product_sheet.dart';

class InventoryDetailScreen extends StatefulWidget {
  final InventoryList inventoryList;

  const InventoryDetailScreen({super.key, required this.inventoryList});

  @override
  State<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends State<InventoryDetailScreen>
    with SingleTickerProviderStateMixin {
  List<InventoryEntry> _entries = [];
  late TabController _tabController;
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEntries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() => _loading = true);
    final entries = await DatabaseHelper.instance.getEntriesByList(widget.inventoryList.id!);
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }

  List<InventoryEntry> get _filteredEntries {
    if (_searchQuery.isEmpty) return _entries;
    final q = _searchQuery.toLowerCase();
    return _entries.where((e) =>
      e.productCode.toLowerCase().contains(q) ||
      e.productDesignation.toLowerCase().contains(q) ||
      e.productBarcode.contains(q),
    ).toList();
  }

  /// Grouper les entrées par produit (totaux)
  List<InventoryTotal> get _totals {
    final map = <String, InventoryTotal>{};
    for (final e in _entries) {
      final key = e.productBarcode.isNotEmpty ? e.productBarcode : e.productCode;
      if (map.containsKey(key)) {
        final existing = map[key]!;
        map[key] = InventoryTotal(
          productCode: existing.productCode,
          productDesignation: existing.productDesignation,
          productBarcode: existing.productBarcode,
          totalQuantity: existing.totalQuantity + e.quantity,
          entryCount: existing.entryCount + 1,
        );
      } else {
        map[key] = InventoryTotal(
          productCode: e.productCode,
          productDesignation: e.productDesignation,
          productBarcode: e.productBarcode,
          totalQuantity: e.quantity,
          entryCount: 1,
        );
      }
    }
    return map.values.toList()..sort((a, b) => a.productDesignation.compareTo(b.productDesignation));
  }

  Future<void> _openScanner() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (result != null) {
      await _handleScanResult(result['barcode'] as String);
    }
  }

  Future<void> _handleScanResult(String barcode) async {
    final product = await DatabaseHelper.instance.getProductByBarcode(barcode);

    if (product == null) {
      if (!mounted) return;
      _showProductNotFoundDialog(barcode);
      return;
    }

    if (!mounted) return;
    final qty = await showDialog<double>(
      context: context,
      builder: (_) => QuantityDialog(product: product),
    );

    if (qty != null) {
      final entry = InventoryEntry.fromProduct(product, widget.inventoryList.id!, qty);
      await DatabaseHelper.instance.insertEntry(entry);
      _loadEntries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('${product.designation} → $qty')),
            ]),
            backgroundColor: AppTheme.secondaryColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showProductNotFoundDialog(String barcode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.search_off, color: AppTheme.warningColor, size: 48),
        title: const Text('Produit introuvable'),
        content: Text('Aucun produit avec le code-barres:\n$barcode'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _addManualProduct(barcode);
            },
            child: const Text('Ajouter manuellement'),
          ),
        ],
      ),
    );
  }

  Future<void> _addManualProduct([String? barcode]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ManualProductDialog(prefillBarcode: barcode),
    );

    if (result != null) {
      final entry = InventoryEntry(
        inventoryListId: widget.inventoryList.id!,
        productCode: result['code'] ?? '',
        productDesignation: result['designation'] ?? '',
        productBarcode: result['barcode'] ?? '',
        quantity: result['quantity'] ?? 1.0,
        isManual: true,
        note: result['note'],
      );
      await DatabaseHelper.instance.insertEntry(entry);
      _loadEntries();
    }
  }

  Future<void> _searchAndAdd() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SearchProductSheet(
        onProductSelected: (product, qty) async {
          final entry = InventoryEntry.fromProduct(product, widget.inventoryList.id!, qty);
          await DatabaseHelper.instance.insertEntry(entry);
          _loadEntries();
        },
      ),
    );
  }

  Future<void> _editEntry(InventoryEntry entry) async {
    final ctrl = TextEditingController(text: entry.quantity.toString());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(entry.productDesignation, maxLines: 2),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Quantité (négatif pour correction)',
            prefixIcon: Icon(Icons.edit_outlined),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Modifier')),
        ],
      ),
    );
    if (confirmed == true) {
      final qty = double.tryParse(ctrl.text) ?? entry.quantity;
      await DatabaseHelper.instance.updateEntry(entry.copyWith(quantity: qty));
      _loadEntries();
    }
  }

  Future<void> _deleteEntry(InventoryEntry entry) async {
    await DatabaseHelper.instance.deleteEntry(entry.id!);
    _loadEntries();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Entrée supprimée'),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(widget.inventoryList.name, overflow: TextOverflow.ellipsis),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: 'Historique (${_entries.length})'),
            Tab(text: 'Totaux (${_totals.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Exporter',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExportScreen(
                  inventoryList: widget.inventoryList,
                  entries: _entries,
                  totals: _totals,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHistoryTab(),
                _buildTotalsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'search',
            mini: true,
            backgroundColor: AppTheme.secondaryColor,
            onPressed: _searchAndAdd,
            child: const Icon(Icons.search),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'manual',
            mini: true,
            backgroundColor: AppTheme.warningColor,
            onPressed: () => _addManualProduct(),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'scan',
            onPressed: _openScanner,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scanner'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.all(12),
    child: TextField(
      decoration: InputDecoration(
        hintText: 'Rechercher dans cet inventaire...',
        prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchQuery = ''))
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onChanged: (v) => setState(() => _searchQuery = v),
    ),
  );

  Widget _buildHistoryTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final filtered = _filteredEntries;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_searchQuery.isEmpty ? 'Aucune entrée' : 'Aucun résultat',
                style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final entry = filtered[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Slidable(
            key: ValueKey(entry.id),
            startActionPane: ActionPane(
              motion: const DrawerMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) => _editEntry(entry),
                  backgroundColor: AppTheme.warningColor,
                  foregroundColor: Colors.white,
                  icon: Icons.edit,
                  label: 'Modifier',
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                ),
              ],
            ),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) => _deleteEntry(entry),
                  backgroundColor: AppTheme.errorColor,
                  foregroundColor: Colors.white,
                  icon: Icons.delete,
                  label: 'Supprimer',
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                ),
              ],
            ),
            child: _buildEntryCard(entry),
          ),
        );
      },
    );
  }

  Widget _buildEntryCard(InventoryEntry entry) {
    final fmt = DateFormat('dd/MM HH:mm');
    final isNeg = entry.quantity < 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: entry.isManual
                    ? AppTheme.warningColor.withOpacity(0.1)
                    : AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                entry.isManual ? Icons.edit_note : Icons.qr_code_scanner,
                color: entry.isManual ? AppTheme.warningColor : AppTheme.primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.productDesignation,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(entry.productCode,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  if (entry.note != null) ...[
                    const SizedBox(height: 2),
                    Text(entry.note!, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isNeg ? AppTheme.errorColor : AppTheme.secondaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    entry.quantity % 1 == 0
                        ? entry.quantity.toInt().toString()
                        : entry.quantity.toStringAsFixed(2),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 4),
                Text(fmt.format(entry.scannedAt), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalsTab() {
    final totals = _totals;
    if (totals.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Aucun total disponible', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    final grandTotal = totals.fold(0.0, (s, t) => s + t.totalQuantity);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, Color(0xFF3B82F6)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.calculate, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total Général', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  grandTotal % 1 == 0 ? grandTotal.toInt().toString() : grandTotal.toStringAsFixed(2),
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ]),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Produits', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text('${totals.length}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ]),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: totals.length,
            itemBuilder: (ctx, i) {
              final t = totals[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
                    child: const Icon(Icons.inventory, color: AppTheme.secondaryColor, size: 20),
                  ),
                  title: Text(t.productDesignation, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('${t.productCode} • ${t.entryCount} saisie(s)',
                      style: const TextStyle(fontSize: 11)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: t.totalQuantity < 0 ? AppTheme.errorColor : AppTheme.secondaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      t.totalQuantity % 1 == 0
                          ? t.totalQuantity.toInt().toString()
                          : t.totalQuantity.toStringAsFixed(2),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
