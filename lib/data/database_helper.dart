import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/product.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('retailmind.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE products (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  malayalamName TEXT NOT NULL,
  category TEXT,
  brand TEXT,
  price REAL NOT NULL,
  gst_percentage REAL DEFAULT 0.0,
  unit TEXT,
  stock_quantity INTEGER DEFAULT 0,
  barcode TEXT,
  image_path TEXT,
  embedding_vector BLOB,
  aliases TEXT NOT NULL
)
''');

    await db.execute('''
CREATE TABLE bills (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at TEXT NOT NULL,
  total_amount REAL NOT NULL,
  total_gst REAL DEFAULT 0.0,
  discount REAL DEFAULT 0.0,
  status TEXT NOT NULL
)
''');

    await db.execute('''
CREATE TABLE bill_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  bill_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  quantity INTEGER NOT NULL,
  price_at_time REAL NOT NULL,
  FOREIGN KEY (bill_id) REFERENCES bills (id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE SET NULL
)
''');
  }

  // --- Product CRUD ---
  Future<int> insertProduct(Product product) async {
    final db = await instance.database;
    return await db.insert('products', product.toMap());
  }

  Future<List<Product>> getAllProducts() async {
    final db = await instance.database;
    final result = await db.query('products');
    return result.map((json) => Product.fromMap(json)).toList();
  }

  Future<int> updateProduct(Product product) async {
    final db = await instance.database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }
  
  // --- Bill CRUD ---
  Future<int> insertBill(Bill bill) async {
    final db = await instance.database;
    return await db.insert('bills', bill.toMap());
  }

  Future<int> insertBillItem(BillItem item) async {
    final db = await instance.database;
    return await db.insert('bill_items', item.toMap());
  }
}
