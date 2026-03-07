import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_inventory/models/product.dart';
import 'package:flutter_inventory/models/inventory_list.dart';
import 'package:flutter_inventory/models/inventory_entry.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'inventory_pro.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL,
        designation TEXT NOT NULL,
        barcode TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(barcode)
      )
    ''');

    await db.execute('''
      CREATE TABLE inventory_lists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_active INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE inventory_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        inventory_list_id INTEGER NOT NULL,
        product_id INTEGER,
        product_code TEXT NOT NULL,
        product_designation TEXT NOT NULL,
        product_barcode TEXT NOT NULL,
        quantity REAL NOT NULL,
        scanned_at TEXT NOT NULL,
        note TEXT,
        is_manual INTEGER DEFAULT 0,
        FOREIGN KEY (inventory_list_id) REFERENCES inventory_lists(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
    await db.execute('CREATE INDEX idx_products_code ON products(code)');
    await db.execute('CREATE INDEX idx_entries_list ON inventory_entries(inventory_list_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE inventory_entries ADD COLUMN note TEXT');
      await db.execute('ALTER TABLE inventory_entries ADD COLUMN is_manual INTEGER DEFAULT 0');
    }
  }

  // ─── PRODUCTS ─────────────────────────────────────────────────────────────

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert('products', product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> insertProductsBatch(List<Product> products) async {
    final db = await database;
    int inserted = 0;
    await db.transaction((txn) async {
      for (final p in products) {
        await txn.insert('products', p.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        inserted++;
      }
    });
    return inserted;
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final maps = await db.query('products',
        where: 'barcode = ?', whereArgs: [barcode], limit: 1);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<Product?> getProductByCode(String code) async {
    final db = await database;
    final maps = await db.query('products',
        where: 'code = ?', whereArgs: [code], limit: 1);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await database;
    final q = '%$query%';
    final maps = await db.query(
      'products',
      where: 'code LIKE ? OR designation LIKE ? OR barcode LIKE ?',
      whereArgs: [q, q, q],
      limit: 50,
      orderBy: 'designation ASC',
    );
    return maps.map(Product.fromMap).toList();
  }

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final maps = await db.query('products', orderBy: 'designation ASC');
    return maps.map(Product.fromMap).toList();
  }

  Future<int> getProductCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM products')) ??
        0;
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return await db.update('products', product.toMap(),
        where: 'id = ?', whereArgs: [product.id]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearProducts() async {
    final db = await database;
    await db.delete('products');
  }

  // ─── INVENTORY LISTS ──────────────────────────────────────────────────────

  Future<int> insertInventoryList(InventoryList list) async {
    final db = await database;
    return await db.insert('inventory_lists', list.toMap());
  }

  Future<List<InventoryList>> getAllInventoryLists() async {
    final db = await database;
    final maps = await db.query('inventory_lists', orderBy: 'updated_at DESC');
    return maps.map(InventoryList.fromMap).toList();
  }

  Future<InventoryList?> getInventoryList(int id) async {
    final db = await database;
    final maps = await db.query('inventory_lists',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return InventoryList.fromMap(maps.first);
  }

  Future<int> updateInventoryList(InventoryList list) async {
    final db = await database;
    return await db.update('inventory_lists', list.toMap(),
        where: 'id = ?', whereArgs: [list.id]);
  }

  Future<int> deleteInventoryList(int id) async {
    final db = await database;
    await db.delete('inventory_entries',
        where: 'inventory_list_id = ?', whereArgs: [id]);
    return await db.delete('inventory_lists', where: 'id = ?', whereArgs: [id]);
  }

  // ─── INVENTORY ENTRIES ────────────────────────────────────────────────────

  Future<int> insertEntry(InventoryEntry entry) async {
    final db = await database;
    final id = await db.insert('inventory_entries', entry.toMap());
    await db.update('inventory_lists', {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [entry.inventoryListId]);
    return id;
  }

  Future<List<InventoryEntry>> getEntriesByList(int listId) async {
    final db = await database;
    final maps = await db.query('inventory_entries',
        where: 'inventory_list_id = ?',
        whereArgs: [listId],
        orderBy: 'scanned_at DESC');
    return maps.map(InventoryEntry.fromMap).toList();
  }

  Future<int> updateEntry(InventoryEntry entry) async {
    final db = await database;
    return await db.update('inventory_entries', entry.toMap(),
        where: 'id = ?', whereArgs: [entry.id]);
  }

  Future<int> deleteEntry(int id) async {
    final db = await database;
    return await db.delete('inventory_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<InventoryTotal>> getTotalsByList(int listId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT 
        product_code,
        product_designation,
        product_barcode,
        SUM(quantity) as total_quantity,
        COUNT(*) as entry_count
      FROM inventory_entries
      WHERE inventory_list_id = ?
      GROUP BY product_code, product_designation, product_barcode
      ORDER BY product_designation ASC
    ''', [listId]);

    return maps
        .map((m) => InventoryTotal(
              productCode: m['product_code'] as String,
              productDesignation: m['product_designation'] as String,
              productBarcode: m['product_barcode'] as String,
              totalQuantity: (m['total_quantity'] as num).toDouble(),
              entryCount: m['entry_count'] as int,
            ))
        .toList();
  }

  Future<int> getEntryCount(int listId) async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM inventory_entries WHERE inventory_list_id = ?',
            [listId])) ??
        0;
  }
}
