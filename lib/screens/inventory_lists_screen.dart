import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:flutter_inventory/database/database_helper.dart';
import 'package:flutter_inventory/models/inventory_list.dart';
import 'package:flutter_inventory/screens/inventory_detail_screen.dart';
import 'package:flutter_inventory/theme/app_theme.dart';
import 'package:flutter_inventory/l10n/app_localizations.dart';
import 'package:flutter_inventory/widgets/empty_state_widget.dart';

class InventoryListsScreen extends StatefulWidget {
  const InventoryListsScreen({super.key});

  @override
  State<InventoryListsScreen> createState() => _InventoryListsScreenState();
}

class _InventoryListsScreenState extends State<InventoryListsScreen> {
  List<InventoryList> _lists = [];
  Map<int, int> _entryCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    setState(() => _loading = true);
    final lists = await DatabaseHelper.instance.getAllInventoryLists();
    final counts = <int, int>{};
    for (final l in lists) {
      if (l.id != null) {
        counts[l.id!] = await DatabaseHelper.instance.getEntryCount(l.id!);
      }
    }
    if (mounted) setState(() { _lists = lists; _entryCounts = counts; _loading = false; });
  }

  Future<void> _createList() async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.newInventory),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.inventoryName,
                prefixIcon: const Icon(Icons.label_outline),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: l10n.description,
                prefixIcon: const Icon(Icons.notes_outlined),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) Navigator.pop(ctx, true);
            },
            child: Text(l10n.create),
          ),
        ],
      ),
    );

    if (confirmed == true && nameController.text.trim().isNotEmpty) {
      final list = InventoryList(
        name: nameController.text.trim(),
        description: descController.text.trim().isEmpty ? null : descController.text.trim(),
      );
      final id = await DatabaseHelper.instance.insertInventoryList(list);
      if (mounted) {
        final created = list.copyWith(id: id);
        _navigateToDetail(created);
      }
    }
  }

  void _navigateToDetail(InventoryList list) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InventoryDetailScreen(inventoryList: list)),
    ).then((_) => _loadLists());
  }

  Future<void> _renameList(InventoryList list) async {
    final controller = TextEditingController(text: list.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nouveau nom'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Renommer'),
          ),
        ],
      ),
    );
    if (confirmed == true && controller.text.trim().isNotEmpty) {
      await DatabaseHelper.instance.updateInventoryList(list.copyWith(name: controller.text.trim()));
      _loadLists();
    }
  }

  Future<void> _deleteList(InventoryList list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer "${list.name}" et toutes ses entrées ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && list.id != null) {
      await DatabaseHelper.instance.deleteInventoryList(list.id!);
      _loadLists();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(l10n.inventories),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLists,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lists.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.inventory_2_outlined,
                  title: l10n.noInventory,
                  subtitle: l10n.noInventorySubtitle,
                  action: ElevatedButton.icon(
                    onPressed: _createList,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.newInventory),
                  ),
                )
              : AnimationLimiter(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _lists.length,
                    itemBuilder: (ctx, i) => AnimationConfiguration.staggeredList(
                      position: i,
                      duration: const Duration(milliseconds: 375),
                      child: SlideAnimation(
                        verticalOffset: 50,
                        child: FadeInAnimation(child: _buildListCard(_lists[i])),
                      ),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createList,
        icon: const Icon(Icons.add),
        label: Text(l10n.newInventory),
      ),
    );
  }

  Widget _buildListCard(InventoryList list) {
    final count = _entryCounts[list.id] ?? 0;
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: ValueKey(list.id),
        startActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => _renameList(list),
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: 'Renommer',
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => _deleteList(list),
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Supprimer',
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
            ),
          ],
        ),
        child: Card(
          child: InkWell(
            onTap: () => _navigateToDetail(list),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inventory_2, color: AppTheme.primaryColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(list.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        if (list.description != null && list.description!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(list.description!,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _chip(Icons.qr_code_scanner, '$count entrées', AppTheme.primaryColor),
                            const SizedBox(width: 8),
                            _chip(Icons.access_time, fmt.format(list.updatedAt), Colors.grey),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) => Row(
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color)),
    ],
  );
}
