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
      final parsed = <CustomerModel>[];
      for (int i = 0; i < maps.length; i++) {
        try {
          parsed.add(CustomerModel.fromMap(maps[i]));
        } catch (e) {
          debugPrint('⚠️ CustomerProvider: failed to parse customer[$i]: $e');
        }
      }
      _customers = parsed;
      debugPrint('📋 CustomerProvider: loaded ${_customers.length} customers from DB');
    } catch (e) {
      debugPrint('❌ Failed to load customers: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addCustomer({required String name, String phone = ''}) async {
    try {
      // ═══════════════════════════════════════════════════════════
      // PHONE-FIRST DEDUPLICATION
      // Phone number is the unique customer identifier. If a phone
      // already exists, we REUSE that customer (update name if needed).
      // This prevents duplicate records and loyalty point splitting.
      // ═══════════════════════════════════════════════════════════
      if (phone.trim().isNotEmpty) {
        final existing = findByPhone(phone.trim());
        if (existing != null) {
          debugPrint('📋 Customer with phone ${phone.trim()} already exists: ${existing.name} (id: ${existing.id})');
          // Update name if different (latest name wins)
          if (existing.name != name.trim() && name.trim().isNotEmpty) {
            await updateCustomer(existing.copyWith(name: name.trim()));
            debugPrint('   ✏️ Updated name: "${existing.name}" → "${name.trim()}"');
          }
          return true; // Customer already exists — not a failure
        }

        // DOUBLE-CHECK: Also verify against DB directly (race condition safety)
        final dbResults = await _db.query('customers',
            where: 'phone = ? AND is_deleted = 0', whereArgs: [phone.trim()]);
        if (dbResults.isNotEmpty) {
          debugPrint('⚠️ Phone ${phone.trim()} found in DB but not in-memory — reloading');
          await loadCustomers(); // Sync in-memory with DB
          return true;
        }
      }

      // Also check by name to avoid duplicates when phone is empty
      if (phone.trim().isEmpty) {
        final existingByName = findByName(name.trim());
        if (existingByName != null) {
          debugPrint('📋 Customer with name "${name.trim()}" already exists (no phone)');
          return true;
        }
      }

      final customer = CustomerModel(id: _uuid.v4(), name: name.trim(), phone: phone.trim());

      debugPrint('➕ CustomerProvider: adding customer "${customer.name}" (${customer.id})');

      // ═══════════════════════════════════════════════════════════
      // CLOUD-FIRST: Try Supabase, but ALWAYS save locally.
      // Previous bug: if cloud rejected (missing column), customer
      // was NEVER saved anywhere → silent data loss.
      // NEW: Save locally + queue for cloud retry on failure.
      // ═══════════════════════════════════════════════════════════
      bool cloudSaved = false;
      if (kIsWeb) {
        try {
          await _supabase.guaranteedSave('customers', customer.toMap());
          debugPrint('   ✅ Customer saved to cloud FIRST');
          cloudSaved = true;
        } catch (e) {
          debugPrint('   ⚠️ Customer cloud save failed (saving locally + queuing): $e');
          // Queue for retry — do NOT block local save
          _supabase.syncRecord('customers', customer.id, 'insert', customer.toMap());
        }
      }

      // ALWAYS save to local DB — never lose customer data
      await _db.insert('customers', customer.toMap());
      debugPrint('   ✓ Saved to local DB');

      // Add to in-memory list (UI updates immediately)
      _customers.add(customer);
      _customers.sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
      debugPrint('   ✓ Added to provider list (total: ${_customers.length})');

      // Mobile: sync in background (SQLite persists, so safe)
      if (!kIsWeb && !cloudSaved) {
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

      // Cloud-first on web — but don't block on failure
      if (kIsWeb) {
        try {
          await _supabase.guaranteedSave('customers', updated.toMap());
          debugPrint('   ✅ Customer update saved to cloud');
        } catch (e) {
          debugPrint('⚠️ Customer update cloud save failed, queuing: $e');
          _supabase.syncRecord('customers', updated.id, 'update', updated.toMap());
        }
      }

      await _db.update('customers', updated.toMap(), updated.id);

      final idx = _customers.indexWhere((c) => c.id == updated.id);
      if (idx != -1) _customers[idx] = updated;
      notifyListeners();

      // Mobile: background sync
      if (!kIsWeb) {
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
  /// CLOUD-FIRST: Stats update must reach Supabase on web
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

    // Cloud-first on web — but don't block on failure
    if (kIsWeb) {
      try {
        await _supabase.guaranteedSave('customers', updated.toMap());
      } catch (e) {
        debugPrint('⚠️ Customer stats cloud save failed, queuing: $e');
        _supabase.syncRecord('customers', updated.id, 'update', updated.toMap());
      }
    }

    await _db.update('customers', updated.toMap(), updated.id);
    _customers[idx] = updated;
    notifyListeners();

    if (!kIsWeb) {
      _supabase.syncRecord('customers', updated.id, 'update', updated.toMap());
    }
  }

  /// Record sale by customer name (finds or creates, then updates stats)
  /// This is the MAIN entry point called after every sale in the billing flow.
  /// Phone number is the unique identifier — if it exists, reuse; if new, create.
  ///
  /// CRITICAL: Customer matching is phone-first. Name fallback is only used
  /// when there is exactly ONE matching customer (no ambiguity risk).
  Future<void> recordSaleByName(String name, String phone, double amount, {int earnRate = 1}) async {
    if (name.isEmpty || name == 'Walk-in Customer') return;

    // ─── STEP 1: Find existing customer by phone (unique key) ───
    CustomerModel? customer;
    if (phone.trim().isNotEmpty) {
      customer = findByPhone(phone.trim());
    }

    // ─── STEP 1b: Name fallback ONLY when phone is empty AND exactly one match ───
    // NEVER use name fallback when phone is provided but not found (could be new customer)
    if (customer == null && phone.trim().isEmpty && name.trim().isNotEmpty) {
      final nameMatches = _customers.where(
        (c) => c.name.toLowerCase().trim() == name.toLowerCase().trim(),
      ).toList();
      if (nameMatches.length == 1) {
        customer = nameMatches.first;
        debugPrint('📋 recordSaleByName: single name match for "${name.trim()}" — using ${customer.phone}');
      } else if (nameMatches.length > 1) {
        debugPrint('⚠️ recordSaleByName: ${nameMatches.length} customers named "${name.trim()}" — '
            'skipping name match to prevent collision');
        // Don't match — will create a new entry (ambiguous)
      }
    }

    // ─── STEP 2: Not found → create new customer ───
    if (customer == null) {
      final success = await addCustomer(name: name.trim(), phone: phone.trim());
      if (!success) {
        debugPrint('❌ recordSaleByName: Failed to create customer — stats will be lost');
        return; // addCustomer already handles the error
      }
      // Re-fetch from in-memory list (addCustomer adds it)
      customer = (phone.trim().isNotEmpty ? findByPhone(phone.trim()) : null) ??
          findByName(name.trim());
      if (customer == null) {
        debugPrint('❌ recordSaleByName: Customer created but not found in list');
        return;
      }
      debugPrint('✅ New customer created: "${customer.name}" (${customer.phone})');
    } else {
      // Update name if different (latest name wins)
      if (name.trim().isNotEmpty && customer.name != name.trim()) {
        await updateCustomer(customer.copyWith(name: name.trim()));
        customer = findByPhone(phone.trim()) ?? customer;
      }
      // Update phone if customer had no phone before
      if (phone.trim().isNotEmpty && customer.phone.isEmpty) {
        await updateCustomer(customer.copyWith(phone: phone.trim()));
        customer = findByPhone(phone.trim()) ?? customer;
      }
    }

    // ─── STEP 3: Update purchase stats ───
    await recordSale(customer.id, amount, earnRate: earnRate);
    debugPrint('📊 Customer "${customer.name}" stats updated: +₹$amount (+${(amount / 100 * earnRate).floor()} pts)');
  }

  /// ═══════════════════════════════════════════════════════
  /// RECOVERY: Scan all sales and recreate any missing customers.
  /// Call this once after fixing the Supabase schema to recover
  /// any customers lost due to the gst_number column bug.
  /// ═══════════════════════════════════════════════════════
  Future<int> recoverMissingCustomers(List<dynamic> allSales) async {
    int recovered = 0;
    final seen = <String>{}; // track phone/name keys to avoid duplicates

    for (final sale in allSales) {
      final name = (sale.customerName as String?) ?? '';
      final phone = (sale.customerPhone as String?) ?? '';
      if (name.isEmpty || name == 'Walk-in Customer') continue;

      // PHONE is primary key — name-only dedup uses prefix to avoid collision
      final key = phone.isNotEmpty ? phone : 'name:${name.toLowerCase().trim()}';
      if (seen.contains(key)) continue;
      seen.add(key);

      // Check if customer already exists — phone-first, name only when no phone
      final existing = phone.isNotEmpty
          ? findByPhone(phone)
          : findByName(name);
      if (existing != null) continue;

      // Customer is missing — recreate
      final success = await addCustomer(name: name.trim(), phone: phone.trim());
      if (success) {
        recovered++;
        debugPrint('🔄 Recovered missing customer: "$name" ($phone)');
      }
    }

    if (recovered > 0) {
      debugPrint('✅ Customer recovery complete: $recovered customers restored');
    }
    return recovered;
  }

  /// Redeem loyalty points for a customer
  Future<void> redeemPoints(String customerId, int pointsUsed) async {
    final idx = _customers.indexWhere((c) => c.id == customerId);
    if (idx == -1) return;

    final current = _customers[idx].loyaltyPoints;
    final newPoints = (current - pointsUsed).clamp(0, current);
    final updated = _customers[idx].copyWith(loyaltyPoints: newPoints);

    // Cloud-first on web
    if (kIsWeb) {
      try {
        await _supabase.guaranteedSave('customers', updated.toMap());
      } catch (e) {
        debugPrint('⚠️ Points redemption cloud save failed, queuing: $e');
        _supabase.syncRecord('customers', updated.id, 'update', updated.toMap());
      }
    }

    await _db.update('customers', updated.toMap(), updated.id);
    _customers[idx] = updated;
    notifyListeners();

    if (!kIsWeb) {
      _supabase.syncRecord('customers', updated.id, 'update', updated.toMap());
    }
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

  // ─── UDHAR / Credit Features ───

  /// Customers with outstanding balance (Udhar)
  List<CustomerModel> get customersWithDues {
    final list = _customers.where((c) => c.balance > 0).toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));
    return list;
  }

  /// Total outstanding receivables across all customers
  double get totalCustomerDues =>
      _customers.fold(0.0, (sum, c) => sum + c.balance);

  /// Collect payment from customer — reduces their outstanding balance.
  /// [method] is 'Cash' or 'UPI' for dashboard tracking.
  /// Returns true on success, false if amount exceeds balance or error.
  Future<bool> collectPayment(String customerId, double amount, String method) async {
    try {
      final idx = _customers.indexWhere((c) => c.id == customerId);
      if (idx == -1) return false;

      final customer = _customers[idx];
      if (amount <= 0 || amount > customer.balance + 0.01) return false;

      final newBalance = double.parse(
        (customer.balance - amount).clamp(0.0, double.infinity).toStringAsFixed(2)
      );
      final updated = customer.copyWith(balance: newBalance);

      // Cloud-first on web
      if (kIsWeb) {
        try {
          await _supabase.guaranteedSave('customers', updated.toMap());
          debugPrint('   ✅ Collection saved to cloud');
        } catch (e) {
          debugPrint('⚠️ Collection cloud save failed, queuing: $e');
          _supabase.syncRecord('customers', updated.id, 'update', updated.toMap());
        }
      }

      await _db.update('customers', updated.toMap(), updated.id);
      _customers[idx] = updated;
      notifyListeners();

      if (!kIsWeb) {
        _supabase.syncRecord('customers', updated.id, 'update', updated.toMap());
      }

      debugPrint('💰 Collected ₹$amount ($method) from "${updated.name}" — balance: ₹$newBalance');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to collect payment: $e');
      return false;
    }
  }
}

