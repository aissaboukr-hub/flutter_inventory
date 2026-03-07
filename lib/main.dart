import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_inventory/database/database_helper.dart';
import 'package:flutter_inventory/screens/home_screen.dart';
import 'package:flutter_inventory/theme/app_theme.dart';
import 'package:flutter_inventory/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await DatabaseHelper.instance.database;
  runApp(const InventoryApp());
}

class InventoryApp extends StatefulWidget {
  const InventoryApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    final state = context.findAncestorStateOfType<_InventoryAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<InventoryApp> createState() => _InventoryAppState();
}

class _InventoryAppState extends State<InventoryApp> {
  Locale _locale = const Locale('fr');

  void setLocale(Locale locale) => setState(() => _locale = locale);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventaire Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      locale: _locale,
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeScreen(),
    );
  }
}
