import 'package:flutter/foundation.dart';
import '../data/local/db_helper.dart';
import '../data/remote/supabase_service.dart';
import '../data/models/clearance_item_model.dart';
import '../data/models/item_model.dart';
import '../providers/inventory_provider.dart';

/// Manages clearance stock — split items, restore, and audit trail.
/// The clearance_items table is the audit log; actual items live in the items table.
/// All mutations sync to Supabase for zero data loss.
class ClearanceProvider extends ChangeNotifier {
  final DBHelper _db = DBHelper.instance;
  final SupabaseService _supabase = SupabaseService.instance;
  List<ClearanceItemModel> _records = [];

  List<ClearanceItemModel> get records => _records;
  List<ClearanceItemModel> get activeRecords =>
      _records.where((r) => r.status == 'active').toList();

  // ─── Load ───

  Future<void> loadClearanceRecords() async {
    final rows = await _db.query('clearance_items', orderBy: 'created_at DESC');
    _records = rows.map((r) => ClearanceItemModel.fromMap(r)).toList();
    notifyListeners();
  }

  // ─── Sync helper ───

  Future<void> _syncToCloud(String action, ClearanceItemModel record) async {
    try {
      if (kIsWeb) {
        await _supabase.syncRecord('clearance_items', record.id, action, record.toMap());
      } else {
        _supabase.syncRecord('clearance_items', record.id, action, record.toMap());
      }
    } catch (e) {
      debugPrint('⚠️ Clearance sync failed (queued): $e');
    }
  }

  // ─── Split item for clearance ───

  /// Splits [qty] units from [originalItem] at [clearancePrice] with [reason].
  /// Creates a new item in the items table + an audit record in clearance_items.
  /// Returns the new clearance item's ID.
  Future<String> splitForClearance({
    required ItemModel originalItem,
    required int qty,
    required double clearancePrice,
    required String reason,
    required InventoryProvider inventoryProvider,
  }) async {
    assert(qty > 0 && qty <= originalItem.quantity, 'Invalid clearance qty');

    final clearanceItemId = 'CLR-${originalItem.id}-${DateTime.now().millisecondsSinceEpoch}';

    // 1. Create the clearance copy in the items table (syncs via InventoryProvider)
    final clearanceItem = ItemModel(
      id: clearanceItemId,
      name: originalItem.name,
      vendor: originalItem.vendor,
      barcode: originalItem.barcode,  // Same barcode
      category: originalItem.category,
      size: originalItem.size,
      color: originalItem.color,
      storageLocation: 'CLEARANCE: $reason',
      price: clearancePrice,
      originalPrice: originalItem.price,
      parentItemId: originalItem.id,
      costPrice: originalItem.costPrice,
      quantity: qty,
      lowStockThreshold: 0,  // No low-stock alerts for clearance items
    );
    await inventoryProvider.addItemDirect(clearanceItem);

    // 2. Reduce quantity on the original item (syncs via InventoryProvider)
    await inventoryProvider.updateItem(
      originalItem.copyWith(quantity: originalItem.quantity - qty),
    );

    // 3. Create the audit record in clearance_items + sync to Supabase
    final auditId = 'CA-${DateTime.now().millisecondsSinceEpoch}';
    final record = ClearanceItemModel(
      id: auditId,
      originalItemId: originalItem.id,
      clearanceItemId: clearanceItemId,
      quantity: qty,
      originalPrice: originalItem.price,
      clearancePrice: clearancePrice,
      reason: reason,
      status: 'active',
    );
    await _db.insert('clearance_items', record.toMap());
    await _syncToCloud('insert', record);
    _records.insert(0, record);
    notifyListeners();

    return clearanceItemId;
  }

  // ─── Restore from clearance ───

  /// Merges the clearance item's remaining quantity back into the original item.
  /// Deletes the clearance item from items table, marks audit record as 'restored'.
  Future<void> restoreFromClearance({
    required ClearanceItemModel record,
    required InventoryProvider inventoryProvider,
  }) async {
    // 1. Find the clearance item in inventory
    final clearanceItem = inventoryProvider.items
        .firstWhere((i) => i.id == record.clearanceItemId, orElse: () => throw StateError('Clearance item not found'));

    // 2. Find the original item
    final originalItem = inventoryProvider.items
        .firstWhere((i) => i.id == record.originalItemId, orElse: () => throw StateError('Original item not found'));

    // 3. Merge quantity back to original (syncs via InventoryProvider)
    await inventoryProvider.updateItem(
      originalItem.copyWith(quantity: originalItem.quantity + clearanceItem.quantity),
    );

    // 4. Delete the clearance copy from items (syncs via InventoryProvider)
    await inventoryProvider.deleteItem(clearanceItem.id);

    // 5. Update audit record + sync to Supabase
    final updated = record.copyWith(status: 'restored');
    await _db.update('clearance_items', updated.toMap(), record.id);
    await _syncToCloud('update', updated);

    final idx = _records.indexWhere((r) => r.id == record.id);
    if (idx >= 0) _records[idx] = updated;
    notifyListeners();
  }

  // ─── Find audit record for a clearance item ───

  ClearanceItemModel? findByItemId(String clearanceItemId) {
    try {
      return _records.firstWhere(
          (r) => r.clearanceItemId == clearanceItemId && r.status == 'active');
    } catch (_) {
      return null;
    }
  }

  ClearanceItemModel? findByOriginalId(String originalItemId) {
    try {
      return _records.firstWhere(
          (r) => r.originalItemId == originalItemId && r.status == 'active');
    } catch (_) {
      return null;
    }
  }

  List<ClearanceItemModel> findAllByOriginalId(String originalItemId) {
    return _records
        .where((r) => r.originalItemId == originalItemId && r.status == 'active')
        .toList();
  }

  // ─── Edit clearance item (price and/or quantity) ───

  /// Updates clearance price and/or quantity on an active clearance item.
  /// If quantity changes, adjusts original item stock accordingly.
  Future<void> updateClearanceItem({
    required ClearanceItemModel record,
    required double newPrice,
    required int newQty,
    required String newReason,
    required InventoryProvider inventoryProvider,
  }) async {
    // 1. Find the clearance item in inventory
    final clearanceItem = inventoryProvider.items
        .firstWhere((i) => i.id == record.clearanceItemId,
            orElse: () => throw StateError('Clearance item not found'));

    // 2. Handle quantity change — adjust original item stock
    final qtyDiff = newQty - clearanceItem.quantity;
    if (qtyDiff != 0) {
      final originalItem = inventoryProvider.items
          .firstWhere((i) => i.id == record.originalItemId,
              orElse: () => throw StateError('Original item not found'));

      // qtyDiff > 0 means we're moving MORE to clearance → reduce original
      // qtyDiff < 0 means we're moving LESS to clearance → return to original
      final newOriginalQty = originalItem.quantity - qtyDiff;
      if (newOriginalQty < 0) throw StateError('Not enough stock in original item');

      await inventoryProvider.updateItem(
        originalItem.copyWith(quantity: newOriginalQty),
      );
    }

    // 3. Update the clearance item in items table (syncs via InventoryProvider)
    await inventoryProvider.updateItem(
      clearanceItem.copyWith(
        price: newPrice,
        quantity: newQty,
        storageLocation: 'CLEARANCE: $newReason',
      ),
    );

    // 4. Update the audit record + sync to Supabase
    final updated = record.copyWith(
      clearancePrice: newPrice,
      quantity: newQty,
      reason: newReason,
    );
    await _db.update('clearance_items', updated.toMap(), record.id);
    await _syncToCloud('update', updated);

    final idx = _records.indexWhere((r) => r.id == record.id);
    if (idx >= 0) _records[idx] = updated;
    notifyListeners();
  }
}
