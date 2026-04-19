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
}
