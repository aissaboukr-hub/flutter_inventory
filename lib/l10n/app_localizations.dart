import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('fr'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedStrings = {
    'fr': {
      'app_title': 'Inventaire Pro',
      'inventories': 'Inventaires',
      'import_export': 'Import/Export',
      'settings': 'Paramètres',
      'new_inventory': 'Nouvel inventaire',
      'inventory_name': 'Nom de l\'inventaire',
      'description': 'Description (optionnel)',
      'cancel': 'Annuler',
      'create': 'Créer',
      'no_inventory': 'Aucun inventaire',
      'no_inventory_subtitle': 'Appuyez sur + pour créer votre premier inventaire',
      'scan': 'Scanner',
      'search': 'Rechercher',
      'history': 'Historique',
      'totals': 'Totaux',
      'export': 'Exporter',
      'import': 'Importer',
      'quantity': 'Quantité',
      'validate': 'Valider',
      'product_not_found': 'Produit introuvable',
      'add_manually': 'Ajouter manuellement',
      'error': 'Erreur',
      'success': 'Succès',
      'language': 'Langue',
      'about': 'À propos',
      'version': 'Version',
      'delete': 'Supprimer',
      'edit': 'Modifier',
      'rename': 'Renommer',
      'refresh': 'Actualiser',
    },
    'en': {
      'app_title': 'Inventory Pro',
      'inventories': 'Inventories',
      'import_export': 'Import/Export',
      'settings': 'Settings',
      'new_inventory': 'New inventory',
      'inventory_name': 'Inventory name',
      'description': 'Description (optional)',
      'cancel': 'Cancel',
      'create': 'Create',
      'no_inventory': 'No inventory',
      'no_inventory_subtitle': 'Tap + to create your first inventory',
      'scan': 'Scan',
      'search': 'Search',
      'history': 'History',
      'totals': 'Totals',
      'export': 'Export',
      'import': 'Import',
      'quantity': 'Quantity',
      'validate': 'Validate',
      'product_not_found': 'Product not found',
      'add_manually': 'Add manually',
      'error': 'Error',
      'success': 'Success',
      'language': 'Language',
      'about': 'About',
      'version': 'Version',
      'delete': 'Delete',
      'edit': 'Edit',
      'rename': 'Rename',
      'refresh': 'Refresh',
    },
    'ar': {
      'app_title': 'برو الجرد',
      'inventories': 'قوائم الجرد',
      'import_export': 'استيراد/تصدير',
      'settings': 'الإعدادات',
      'new_inventory': 'قائمة جرد جديدة',
      'inventory_name': 'اسم القائمة',
      'description': 'الوصف (اختياري)',
      'cancel': 'إلغاء',
      'create': 'إنشاء',
      'no_inventory': 'لا توجد قوائم جرد',
      'no_inventory_subtitle': 'اضغط + لإنشاء أول قائمة جرد',
      'scan': 'مسح',
      'search': 'بحث',
      'history': 'السجل',
      'totals': 'المجاميع',
      'export': 'تصدير',
      'import': 'استيراد',
      'quantity': 'الكمية',
      'validate': 'تأكيد',
      'product_not_found': 'المنتج غير موجود',
      'add_manually': 'إضافة يدوياً',
      'error': 'خطأ',
      'success': 'نجاح',
      'language': 'اللغة',
      'about': 'حول',
      'version': 'الإصدار',
      'delete': 'حذف',
      'edit': 'تعديل',
      'rename': 'إعادة تسمية',
      'refresh': 'تحديث',
    },
  };

  String _t(String key) {
    final lang = locale.languageCode;
    return _localizedStrings[lang]?[key] ?? _localizedStrings['fr']![key] ?? key;
  }

  String get appTitle => _t('app_title');
  String get inventories => _t('inventories');
  String get importExport => _t('import_export');
  String get settings => _t('settings');
  String get newInventory => _t('new_inventory');
  String get inventoryName => _t('inventory_name');
  String get description => _t('description');
  String get cancel => _t('cancel');
  String get create => _t('create');
  String get noInventory => _t('no_inventory');
  String get noInventorySubtitle => _t('no_inventory_subtitle');
  String get scan => _t('scan');
  String get search => _t('search');
  String get history => _t('history');
  String get totals => _t('totals');
  String get export => _t('export');
  String get import => _t('import');
  String get quantity => _t('quantity');
  String get validate => _t('validate');
  String get productNotFound => _t('product_not_found');
  String get addManually => _t('add_manually');
  String get error => _t('error');
  String get success => _t('success');
  String get language => _t('language');
  String get about => _t('about');
  String get version => _t('version');
  String get delete => _t('delete');
  String get edit => _t('edit');
  String get rename => _t('rename');
  String get refresh => _t('refresh');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['fr', 'en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
