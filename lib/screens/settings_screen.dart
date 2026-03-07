import 'package:flutter/material.dart';
import 'package:flutter_inventory/l10n/app_localizations.dart';
import 'package:flutter_inventory/main.dart';
import 'package:flutter_inventory/theme/app_theme.dart';
import 'package:flutter_inventory/services/google_sheets_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _credentialsCtrl = TextEditingController();
  final _spreadsheetCtrl = TextEditingController();
  bool _gsheetsConnected = false;
  bool _testing = false;

  @override
  void dispose() {
    _credentialsCtrl.dispose();
    _spreadsheetCtrl.dispose();
    super.dispose();
  }

  Future<void> _testGSheetsConnection() async {
    if (_credentialsCtrl.text.isEmpty || _spreadsheetCtrl.text.isEmpty) {
      _showSnack('Remplissez les champs requis', AppTheme.warningColor);
      return;
    }
    setState(() => _testing = true);
    final ok = await GoogleSheetsService.init(
      GoogleSheetsConfig(
        credentials: _credentialsCtrl.text.trim(),
        spreadsheetId: _spreadsheetCtrl.text.trim(),
      ),
    );
    setState(() { _gsheetsConnected = ok; _testing = false; });
    _showSnack(ok ? 'Connexion Google Sheets réussie !' : 'Échec de connexion',
        ok ? AppTheme.secondaryColor : AppTheme.errorColor);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Langue
          _sectionTitle('Langue'),
          const SizedBox(height: 12),
          Card(
            child: Column(children: [
              _langTile('Français', '🇫🇷', const Locale('fr')),
              const Divider(height: 1),
              _langTile('English', '🇬🇧', const Locale('en')),
              const Divider(height: 1),
              _langTile('العربية', '🇲🇦', const Locale('ar')),
            ]),
          ),
          const SizedBox(height: 24),

          // Google Sheets
          _sectionTitle('Google Sheets'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.table_chart, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text('Configuration', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (_gsheetsConnected)
                      const Icon(Icons.check_circle, color: AppTheme.secondaryColor),
                  ]),
                  const SizedBox(height: 12),
                  const Text(
                    '1. Créez un projet Google Cloud\n'
                    '2. Activez l\'API Google Sheets\n'
                    '3. Créez un compte de service\n'
                    '4. Téléchargez le fichier JSON des credentials\n'
                    '5. Collez le contenu JSON ci-dessous',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _credentialsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Credentials JSON',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _spreadsheetCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ID du Spreadsheet',
                      hintText: 'Ex: 1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _testing ? null : _testGSheetsConnection,
                      icon: _testing
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.wifi_tethering),
                      label: Text(_testing ? 'Test en cours...' : 'Tester la connexion'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // À propos
          _sectionTitle('À propos'),
          const SizedBox(height: 12),
          Card(
            child: Column(children: [
              const ListTile(
                leading: Icon(Icons.inventory_2, color: AppTheme.primaryColor),
                title: Text('Inventaire Pro'),
                subtitle: Text('Version 1.0.0'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: const Text('Base de données'),
                subtitle: const Text('SQLite local'),
                trailing: const Icon(Icons.check_circle, color: AppTheme.secondaryColor),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
  );

  Widget _langTile(String name, String flag, Locale locale) => ListTile(
    leading: Text(flag, style: const TextStyle(fontSize: 24)),
    title: Text(name),
    onTap: () => InventoryApp.setLocale(context, locale),
  );
}
