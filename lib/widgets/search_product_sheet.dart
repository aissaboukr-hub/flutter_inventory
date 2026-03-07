import 'package:flutter/material.dart';
import 'package:flutter_inventory/database/database_helper.dart';
import 'package:flutter_inventory/models/product.dart';
import 'package:flutter_inventory/theme/app_theme.dart';
import 'package:flutter_inventory/widgets/quantity_dialog.dart';

class SearchProductSheet extends StatefulWidget {
  final Future<void> Function(Product product, double quantity) onProductSelected;

  const SearchProductSheet({super.key, required this.onProductSelected});

  @override
  State<SearchProductSheet> createState() => _SearchProductSheetState();
}

class _SearchProductSheetState extends State<SearchProductSheet> {
  final _ctrl = TextEditingController();
  List<Product> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final results = await DatabaseHelper.instance.searchProducts(query.trim());
    if (mounted) setState(() { _results = results; _searching = false; });
  }

  Future<void> _selectProduct(Product product) async {
    final qty = await showDialog<double>(
      context: context,
      builder: (_) => QuantityDialog(product: product),
    );
    if (qty != null && mounted) {
      await widget.onProductSelected(product, qty);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Titre + recherche
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rechercher un produit',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Code, désignation ou code-barres...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                    suffixIcon: _searching
                        ? const Padding(padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2)))
                        : _ctrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () { _ctrl.clear(); _search(''); })
                            : null,
                  ),
                  onChanged: _search,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Résultats
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          _ctrl.text.isEmpty
                              ? 'Tapez pour rechercher'
                              : 'Aucun produit trouvé',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _results.length,
                    itemBuilder: (ctx, i) {
                      final p = _results[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.inventory, color: AppTheme.primaryColor, size: 22),
                          ),
                          title: Text(p.designation,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              maxLines: 2),
                          subtitle: Text('${p.code} • ${p.barcode}',
                              style: const TextStyle(fontSize: 11)),
                          trailing: ElevatedButton(
                            onPressed: () => _selectProduct(p),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: const Text('Ajouter'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
