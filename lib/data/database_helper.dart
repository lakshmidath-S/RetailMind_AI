import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/product.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';
import '../models/customer.dart';
import '../models/customer_ledger.dart';

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

    return await openDatabase(path, version: 2, onCreate: _createDB, onUpgrade: _upgradeDB);
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
CREATE TABLE customers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone TEXT,
  pending_amount REAL DEFAULT 0.0
)
''');

    await db.execute('''
CREATE TABLE bills (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at TEXT NOT NULL,
  total_amount REAL NOT NULL,
  total_gst REAL DEFAULT 0.0,
  discount REAL DEFAULT 0.0,
  status TEXT NOT NULL,
  payment_mode TEXT NOT NULL DEFAULT 'CASH',
  customer_id INTEGER,
  FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
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

    await db.execute('''
CREATE TABLE customer_ledger (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id INTEGER NOT NULL,
  amount_paid REAL NOT NULL,
  date TEXT NOT NULL,
  note TEXT,
  FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
)
''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new tables for v2
      await db.execute('''
CREATE TABLE IF NOT EXISTS customers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone TEXT,
  pending_amount REAL DEFAULT 0.0
)
''');
      await db.execute('''
CREATE TABLE IF NOT EXISTS customer_ledger (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id INTEGER NOT NULL,
  amount_paid REAL NOT NULL,
  date TEXT NOT NULL,
  note TEXT,
  FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
)
''');
      // Add columns to bills table
      await db.execute("ALTER TABLE bills ADD COLUMN payment_mode TEXT NOT NULL DEFAULT 'CASH'");
      await db.execute("ALTER TABLE bills ADD COLUMN customer_id INTEGER");
    }
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

  Future<List<Bill>> getBillsByCustomer(int customerId) async {
    final db = await instance.database;
    final result = await db.query(
      'bills',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => Bill.fromMap(map)).toList();
  }

  // --- Customer CRUD ---
  Future<int> insertCustomer(Customer customer) async {
    final db = await instance.database;
    return await db.insert('customers', customer.toMap());
  }

  Future<List<Customer>> getAllCustomers() async {
    final db = await instance.database;
    final result = await db.query('customers', orderBy: 'name ASC');
    return result.map((map) => Customer.fromMap(map)).toList();
  }

  Future<Customer?> getCustomerById(int id) async {
    final db = await instance.database;
    final result = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Customer.fromMap(result.first);
  }

  Future<int> updateCustomer(Customer customer) async {
    final db = await instance.database;
    return await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  /// Increases a customer's pending balance (called when a PAY_LATER bill is created).
  Future<void> addToPendingAmount(int customerId, double amount) async {
    final db = await instance.database;
    await db.rawUpdate(
      'UPDATE customers SET pending_amount = pending_amount + ? WHERE id = ?',
      [amount, customerId],
    );
  }

  // --- Customer Ledger (Settlements) ---
  Future<int> insertLedgerEntry(CustomerLedgerEntry entry) async {
    final db = await instance.database;
    // Reduce the customer's pending amount
    await db.rawUpdate(
      'UPDATE customers SET pending_amount = MAX(0, pending_amount - ?) WHERE id = ?',
      [entry.amountPaid, entry.customerId],
    );
    return await db.insert('customer_ledger', entry.toMap());
  }

  Future<List<CustomerLedgerEntry>> getLedgerEntries(int customerId) async {
    final db = await instance.database;
    final result = await db.query(
      'customer_ledger',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'date DESC',
    );
    return result.map((map) => CustomerLedgerEntry.fromMap(map)).toList();
  }

  /// Creates a complete bill with items and handles PAY_LATER logic.
  Future<int> createCompleteBill({
    required Bill bill,
    required List<BillItem> items,
  }) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final billId = await txn.insert('bills', bill.toMap());

      for (final item in items) {
        await txn.insert('bill_items', BillItem(
          billId: billId,
          productId: item.productId,
          quantity: item.quantity,
          priceAtTime: item.priceAtTime,
        ).toMap());

        // Deduct stock
        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = MAX(0, stock_quantity - ?) WHERE id = ?',
          [item.quantity, item.productId],
        );
      }

      // If PAY_LATER, increase customer's pending amount
      if (bill.paymentMode == 'PAY_LATER' && bill.customerId != null) {
        await txn.rawUpdate(
          'UPDATE customers SET pending_amount = pending_amount + ? WHERE id = ?',
          [bill.totalAmount, bill.customerId],
        );
      }

      return billId;
    });
  }
}
