import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/local/db_helper.dart';
import '../data/remote/supabase_service.dart';
import '../data/models/customer_model.dart';

class CustomerProvider extends ChangeNotifier {
  final DBHelper _db = DBHelper.instance;
  final SupabaseService _supabase = SupabaseService.instance;
  final _uuid = const Uuid();

  List<CustomerModel> _customers = [];
  bool _isLoading = false;

  List<CustomerModel> get customers => _customers;
  List<CustomerModel> get topCustomers {
    final sorted = List<CustomerModel>.from(_customers);
    sorted.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
    return sorted.take(10).toList();
  }
  bool get isLoading => _isLoading;

  Future<void> loadCustomers() async {
    _isLoading = true;
    notifyListeners();

    try {
      final maps = await _db.query(
        'customers',
        where: 'is_deleted = 0',
        orderBy: 'name ASC',
      );
      _customers = maps.map((m) => CustomerModel.fromMap(m)).toList();
      debugPrint('📋 CustomerProvider: loaded ${_customers.length} customers from DB');
    } catch (e) {
      debugPrint('❌ Failed to load customers: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addCustomer({required String name, String phone = ''}) async {
    try {
      final customer = CustomerModel(id: _uuid.v4(), name: name, phone: phone);

      debugPrint('➕ CustomerProvider: adding customer "${customer.name}" (${customer.id})');

      // STEP 1: Save to local DB
      await _db.insert('customers', customer.toMap());
      debugPrint('   ✓ Saved to local DB');

      // STEP 2: Add to in-memory list (UI updates immediately)
      _customers.add(customer);
      _customers.sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
      debugPrint('   ✓ Added to provider list (total: ${_customers.length})');

      // STEP 3: Sync to Supabase (await on web!)
      if (kIsWeb) {
        final synced = await _supabase.syncRecord('customers', customer.id, 'insert', customer.toMap());
        if (synced) {
          debugPrint('   ✓ Synced to Supabase');
        } else {
          debugPrint('   ⚠️ Supabase sync queued');
        }
      } else {
        _supabase.syncRecord('customers', customer.id, 'insert', customer.toMap());
      }

      return true;
    } catch (e) {
      debugPrint('❌ Failed to add customer: $e');
      return false;
    }
  }

  Future<bool> updateCustomer(CustomerModel customer) async {
    try {
      final updated = customer.copyWith(updatedAt: DateTime.now());
      await _db.update('customers', updated.toMap(), updated.id);

      final idx = _customers.indexWhere((c) => c.id == updated.id);
      if (idx != -1) _customers[idx] = updated;
      notifyListeners();

      if (kIsWeb) {
        await _supabase.syncRecord('customers', updated.id, 'update', updated.toMap());
      } else {
        _supabase.syncRecord('customers', updated.id, 'update', updated.toMap());
      }
      return true;
    } catch (e) {
      debugPrint('❌ Failed to update customer: $e');
      return false;
    }
  }

  Future<bool> deleteCustomer(String id) async {
    try {
      final c = _customers.firstWhere((c) => c.id == id);
      final deleted = c.copyWith(isDeleted: true);
      await _db.update('customers', deleted.toMap(), deleted.id);

      _customers.removeWhere((c) => c.id == id);
      notifyListeners();

      if (kIsWeb) {
        await _supabase.syncRecord('customers', deleted.id, 'delete', deleted.toMap());
      } else {
        _supabase.syncRecord('customers', deleted.id, 'delete', deleted.toMap());
      }
      return true;
    } catch (e) {
      debugPrint('❌ Failed to delete customer: $e');
      return false;
    }
  }

  /// Increment order count + spending for a customer (called after sale)
  Future<void> recordSale(String customerId, double amount, {int earnRate = 1}) async {
    final idx = _customers.indexWhere((c) => c.id == customerId);
    if (idx == -1) return;

    final pointsEarned = (amount / 100 * earnRate).floor();
    final updated = _customers[idx].copyWith(
      totalOrders: _customers[idx].totalOrders + 1,
      totalSpent: _customers[idx].totalSpent + amount,
      loyaltyPoints: _customers[idx].loyaltyPoints + pointsEarned,
      lastPurchaseDate: DateTime.now(),
    );
    await _db.update('customers', updated.toMap(), updated.id);
    if (kIsWeb) {
      await _supabase.syncRecord('customers', updated.id, 'update', updated.toMap());
    } else {
      _supabase.syncRecord('customers', updated.id, 'update', updated.toMap());
    }
    _customers[idx] = updated;
    notifyListeners();
  }

  /// Record sale by customer name (finds or creates, then updates stats)
  Future<void> recordSaleByName(String name, String phone, double amount, {int earnRate = 1}) async {
    if (name.isEmpty || name == 'Walk-in Customer') return;

    // Find existing customer
    CustomerModel? customer;
    try {
      customer = _customers.firstWhere(
        (c) => c.name.toLowerCase().trim() == name.toLowerCase().trim(),
      );
    } catch (_) {
      // Not found — create new
      await addCustomer(name: name.trim(), phone: phone.trim());
      try {
        customer = _customers.firstWhere(
          (c) => c.name.toLowerCase().trim() == name.toLowerCase().trim(),
        );
      } catch (_) {
        return;
      }
    }

    // Update stats
    await recordSale(customer.id, amount, earnRate: earnRate);
    debugPrint('📊 Customer "${customer.name}" stats updated: +₹$amount (+${(amount / 100 * earnRate).floor()} pts)');
  }

  /// Redeem loyalty points for a customer
  Future<void> redeemPoints(String customerId, int pointsUsed) async {
    final idx = _customers.indexWhere((c) => c.id == customerId);
    if (idx == -1) return;

    final current = _customers[idx].loyaltyPoints;
    final newPoints = (current - pointsUsed).clamp(0, current);
    final updated = _customers[idx].copyWith(loyaltyPoints: newPoints);
    await _db.update('customers', updated.toMap(), updated.id);
    if (kIsWeb) {
      await _supabase.syncRecord('customers', updated.id, 'update', updated.toMap());
    } else {
      _supabase.syncRecord('customers', updated.id, 'update', updated.toMap());
    }
    _customers[idx] = updated;
    notifyListeners();
    debugPrint('⭐ Redeemed $pointsUsed pts for "${updated.name}" (remaining: $newPoints)');
  }

  /// Find or create customer by phone
  CustomerModel? findByPhone(String phone) {
    if (phone.isEmpty) return null;
    try {
      return _customers.firstWhere((c) => c.phone == phone);
    } catch (_) {
      return null;
    }
  }

  /// Find customer by name
  CustomerModel? findByName(String name) {
    if (name.isEmpty) return null;
    try {
      return _customers.firstWhere(
        (c) => c.name.toLowerCase().trim() == name.toLowerCase().trim(),
      );
    } catch (_) {
      return null;
    }
  }
}
