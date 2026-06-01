import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/local/db_helper.dart';
import '../data/remote/supabase_service.dart';
import '../data/models/purchase_model.dart';
import '../data/models/item_model.dart';
import 'inventory_provider.dart';
import 'vendor_provider.dart';

class PurchaseProvider extends ChangeNotifier {
  final DBHelper _db = DBHelper.instance;
  final SupabaseService _supabase = SupabaseService.instance;
  final _uuid = const Uuid();

  List<PurchaseModel> _purchases = [];
  bool _isLoading = false;

  List<PurchaseModel> get purchases => _purchases;
  bool get isLoading => _isLoading;

  /// Load all purchases (newest first)
  Future<void> loadPurchases() async {
    _isLoading = true;
    notifyListeners();

    try {
      final maps = await _db.query(
        'purchases',
        where: 'is_deleted = 0',
        orderBy: 'created_at DESC',
      );
      _purchases = maps.map((m) => PurchaseModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Failed to load purchases: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Record a new purchase
  /// - Increases stock for each item
  /// - Updates vendor balance if there's due amount
  Future<bool> addPurchase({
    required String vendorId,
    required String vendorName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double paidAmount,
    required String paymentMode,
    required InventoryProvider inventoryProvider,
    required VendorProvider vendorProvider,
  }) async {
    try {
      final purchase = PurchaseModel(
        id: _uuid.v4(),
        vendorId: vendorId,
        vendorName: vendorName,
        items: jsonEncode(items),
        totalAmount: totalAmount,
        paidAmount: paidAmount,
        paymentMode: paymentMode,
      );

      // 1. Save purchase record
      await _db.insert('purchases', purchase.toMap());
      await _supabase.syncRecord('purchases', purchase.id, 'insert', purchase.toMap());

      // 2. Increase stock for each item
      for (final item in items) {
        final itemId = item['item_id'] as String?;
        final qty = (item['quantity'] as num?)?.toInt() ?? 0;

        if (itemId != null && qty > 0) {
          // Find existing item and increase quantity
          final existingItem = inventoryProvider.items.cast<ItemModel?>().firstWhere(
            (i) => i?.id == itemId,
            orElse: () => null,
          );

          if (existingItem != null) {
            await inventoryProvider.updateItem(
              existingItem.copyWith(
                quantity: existingItem.quantity + qty,
                costPrice: (item['cost_price'] as num?)?.toDouble() ?? existingItem.costPrice,
              ),
            );
          }
        }
      }

      // 3. Update vendor balance (add due amount)
      final dueAmount = totalAmount - paidAmount;
      if (dueAmount > 0) {
        await vendorProvider.adjustBalance(vendorId, dueAmount);
      }

      _purchases.insert(0, purchase);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to add purchase: $e');
      return false;
    }
  }

  /// Get today's purchase payment total (for cash till)
  double get todayPurchasePayments {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _purchases
        .where((p) => p.createdAt.toIso8601String().substring(0, 10) == today)
        .fold(0.0, (sum, p) => sum + p.paidAmount);
  }

  // ─── Vendor Tracking ───

  /// Get all purchases for a specific vendor (newest first)
  List<PurchaseModel> getVendorPurchases(String vendorId) {
    return _purchases.where((p) => p.vendorId == vendorId).toList();
  }

  /// Single-pass aggregation for ALL vendors — avoids N queries
  Map<String, Map<String, dynamic>> getAllVendorSummaries() {
    final Map<String, Map<String, dynamic>> summaries = {};

    for (final p in _purchases) {
      final vid = p.vendorId;
      summaries.putIfAbsent(vid, () => {
        'totalPurchase': 0.0,
        'totalPaid': 0.0,
        'pending': 0.0,
        'totalItems': 0,
        'purchaseCount': 0,
      });

      final s = summaries[vid]!;
      s['totalPurchase'] = (s['totalPurchase'] as double) + p.totalAmount;
      s['totalPaid'] = (s['totalPaid'] as double) + p.paidAmount;
      s['pending'] = (s['totalPurchase'] as double) - (s['totalPaid'] as double);
      s['purchaseCount'] = (s['purchaseCount'] as int) + 1;

      // Parse items JSON once per purchase
      try {
        final items = p.itemsList;
        int qty = 0;
        for (final item in items) {
          qty += ((item['quantity'] as num?) ?? 0).toInt();
        }
        s['totalItems'] = (s['totalItems'] as int) + qty;
      } catch (_) {}
    }

    return summaries;
  }

  /// Get summary for a single vendor
  Map<String, dynamic> getVendorSummary(String vendorId) {
    final all = getAllVendorSummaries();
    return all[vendorId] ?? {
      'totalPurchase': 0.0,
      'totalPaid': 0.0,
      'pending': 0.0,
      'totalItems': 0,
      'purchaseCount': 0,
    };
  }

  /// Record payment to a vendor — FIFO settlement (oldest pending first)
  Future<bool> recordVendorPayment({
    required String vendorId,
    required double amount,
    required String paymentMode,
    required VendorProvider vendorProvider,
  }) async {
    try {
      // Get all pending purchases for this vendor (oldest first)
      final pending = _purchases
          .where((p) => p.vendorId == vendorId && p.dueAmount > 0)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      if (pending.isEmpty) return false;

      double remaining = amount;

      for (final purchase in pending) {
        if (remaining <= 0) break;

        final due = purchase.dueAmount;
        final payNow = remaining >= due ? due : remaining;
        final newPaid = purchase.paidAmount + payNow;

        // Update local DB
        final updatedMap = purchase.toMap();
        updatedMap['paid_amount'] = newPaid;
        updatedMap['updated_at'] = DateTime.now().toUtc().toIso8601String();
        await _db.update('purchases', updatedMap, purchase.id);

        // Sync to Supabase
        await _supabase.syncRecord('purchases', purchase.id, 'update', updatedMap);

        // Update in-memory
        final idx = _purchases.indexWhere((p) => p.id == purchase.id);
        if (idx != -1) {
          _purchases[idx] = PurchaseModel.fromMap(updatedMap);
        }

        remaining -= payNow;
      }

      // Reduce vendor balance
      await vendorProvider.adjustBalance(vendorId, -amount);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Failed to record vendor payment: $e');
      return false;
    }
  }

  // ─── Invoice Helpers ───

  /// Generate a vendor invoice number: VINV-YYYY-XXXX
  String generateVendorInvoiceNumber(String vendorId) {
    final year = DateTime.now().year;
    final vendorPurchases = getVendorPurchases(vendorId);
    final seq = (vendorPurchases.length + 1).toString().padLeft(4, '0');
    return 'VINV-$year-$seq';
  }

  /// Get payment status string for a vendor
  String getVendorPaymentStatus(String vendorId) {
    final summary = getVendorSummary(vendorId);
    final totalPaid = summary['totalPaid'] as double;
    final pending = summary['pending'] as double;
    if (pending <= 0) return 'Paid';
    if (totalPaid <= 0) return 'Unpaid';
    return 'Partial';
  }

  /// Get purchase summary list formatted for WhatsApp message
  List<Map<String, dynamic>> getVendorPurchasesList(String vendorId) {
    final purchases = getVendorPurchases(vendorId);
    return purchases.map((p) => {
      'date': p.createdAt.toIso8601String().substring(0, 10),
      'amount': p.totalAmount,
      'paid': p.paidAmount,
      'status': p.isFullyPaid ? '✅' : '⏳',
    }).toList();
  }
}
