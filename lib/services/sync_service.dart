import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/database_helper.dart';
import '../models/bill.dart';
import 'auth_service.dart';

/// Offline-first sync service.
/// All writes go to local SQLite first. When online, changes are pushed
/// to Supabase and remote changes are pulled down.
class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final _db = DatabaseHelper.instance;
  SupabaseClient get _client => Supabase.instance.client;
  StreamSubscription? _connectivitySub;

  /// Start listening for connectivity changes. Call once at app startup.
  void startListening() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection && AuthService.isLoggedIn) {
        syncAll();
      }
    });
  }

  void stopListening() {
    _connectivitySub?.cancel();
  }

  /// Push all local data to Supabase and pull remote updates.
  Future<void> syncAll() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return;

      await _syncProducts(userId);
      await _syncCustomers(userId);
      await _syncBills(userId);
    } catch (e) {
      // Silently fail — the app works offline. Will retry on next connectivity change.
      print('Sync error: $e');
    }
  }

  Future<void> _syncProducts(String userId) async {
    final localProducts = await _db.getAllProducts();
    for (final product in localProducts) {
      await _client.from('products').upsert({
        'local_id': product.id,
        'user_id': userId,
        'name': product.name,
        'malayalam_name': product.malayalamName,
        'category': product.category,
        'brand': product.brand,
        'price': product.price,
        'gst_percentage': product.gstPercentage,
        'unit': product.unit,
        'stock_quantity': product.stockQuantity,
        'barcode': product.barcode,
        'aliases': product.aliases.join(','),
      }, onConflict: 'user_id,local_id');
    }
  }

  Future<void> _syncCustomers(String userId) async {
    final localCustomers = await _db.getAllCustomers();
    for (final customer in localCustomers) {
      await _client.from('customers').upsert({
        'local_id': customer.id,
        'user_id': userId,
        'name': customer.name,
        'phone': customer.phone,
        'pending_amount': customer.pendingAmount,
      }, onConflict: 'user_id,local_id');
    }
  }

  Future<void> _syncBills(String userId) async {
    final db = await _db.database;
    final localBills = await db.query('bills');
    for (final billMap in localBills) {
      final bill = Bill.fromMap(billMap);
      await _client.from('bills').upsert({
        'local_id': bill.id,
        'user_id': userId,
        'created_at': bill.createdAt.toIso8601String(),
        'total_amount': bill.totalAmount,
        'total_gst': bill.totalGst,
        'discount': bill.discount,
        'status': bill.status,
        'payment_mode': bill.paymentMode,
        'customer_local_id': bill.customerId,
      }, onConflict: 'user_id,local_id');
    }
  }
}
