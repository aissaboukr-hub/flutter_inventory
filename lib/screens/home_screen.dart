import 'package:flutter/material.dart';
import 'package:flutter_inventory/screens/inventory_lists_screen.dart';
import 'package:flutter_inventory/screens/import_export_screen.dart';
import 'package:flutter_inventory/screens/settings_screen.dart';
import 'package:flutter_inventory/theme/app_theme.dart';
import 'package:flutter_inventory/l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    InventoryListsScreen(),
    ImportExportScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 8,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2, color: AppTheme.primaryColor),
            label: l10n.inventories,
          ),
          NavigationDestination(
            icon: const Icon(Icons.import_export_outlined),
            selectedIcon: const Icon(Icons.import_export, color: AppTheme.primaryColor),
            label: l10n.importExport,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings, color: AppTheme.primaryColor),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}
