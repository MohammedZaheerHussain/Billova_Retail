import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/local/db_helper.dart';
import '../data/remote/supabase_service.dart';
import '../data/models/item_model.dart';
import '../core/utils/permission_helper.dart';

class InventoryProvider extends ChangeNotifier {
  final DBHelper _db = DBHelper.instance;
  final SupabaseService _supabase = SupabaseService.instance;
  final _uuid = const Uuid();

  List<ItemModel> _items = [];
  List<ItemModel> _filteredItems = [];
  bool _isLoading = false;
  String _error = '';
  String _searchQuery = '';

  List<ItemModel> get items => _searchQuery.isEmpty ? _items : _filteredItems;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get searchQuery => _searchQuery;
  int get totalItems => _items.length;
  int get lowStockCount => _items.where((i) => i.isLowStock).length;
  int get outOfStockCount => _items.where((i) => i.isOutOfStock).length;

  Future<void> loadItems() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final maps = await _db.getAll('items', orderBy: 'name ASC');
      _items = maps.map((m) => ItemModel.fromMap(m)).toList();
      _applySearch();
      debugPrint('📋 InventoryProvider: loaded ${_items.length} items from DB');
    } catch (e) {
      _error = 'Failed to load items: $e';
      debugPrint('❌ $_error');
    }

    _isLoading = false;
    notifyListeners();
  }

  void search(String query) {
    _searchQuery = query;
    _applySearch();
    notifyListeners();
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredItems = _items;
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredItems = _items.where((item) {
        return item.name.toLowerCase().contains(q);
      }).toList();
    }
  }

  Future<bool> addItem({
    required String name,
    String vendor = '',
    String barcode = '',
    String category = '',
    String size = '',
    String color = '',
    String storageLocation = '',
    required double price,
    double costPrice = 0,
    double gstRate = 0,
    int quantity = 0,
    int lowStockThreshold = 5,
  }) async {
    try {
      final item = ItemModel(
        id: _uuid.v4(),
        name: name,
        vendor: vendor,
        barcode: barcode,
        category: category,
        size: size,
        color: color,
        storageLocation: storageLocation,
        price: price,
        costPrice: costPrice,
        gstRate: gstRate,
        quantity: quantity,
        lowStockThreshold: lowStockThreshold,
      );

      debugPrint('➕ InventoryProvider: adding item "${item.name}" (${item.id})');

      // STEP 1: Save to local DB
      await _db.insert('items', item.toMap());
      debugPrint('   ✓ Saved to local DB');

      // STEP 2: Add to in-memory list (UI updates immediately)
      _items.insert(0, item);
      _items.sort((a, b) => a.name.compareTo(b.name));
      _applySearch();
      notifyListeners();
      debugPrint('   ✓ Added to provider list (total: ${_items.length})');

      // STEP 3: Sync to Supabase (await on web for persistence!)
      if (kIsWeb) {
        final synced = await _supabase.syncRecord('items', item.id, 'insert', item.toMap());
        if (synced) {
          debugPrint('   ✓ Synced to Supabase');
        } else {
          debugPrint('   ⚠️ Supabase sync queued (will retry)');
        }
      } else {
        _supabase.syncRecord('items', item.id, 'insert', item.toMap());
      }

      return true;
    } catch (e) {
      _error = 'Failed to add item: $e';
      debugPrint('❌ $_error');
      notifyListeners();
      return false;
    }
  }

  /// Add a pre-built ItemModel directly (used by ClearanceProvider for split items)
  Future<bool> addItemDirect(ItemModel item) async {
    try {
      await _db.insert('items', item.toMap());
      _items.insert(0, item);
      _items.sort((a, b) => a.name.compareTo(b.name));
      _applySearch();
      notifyListeners();

      if (kIsWeb) {
        await _supabase.syncRecord('items', item.id, 'insert', item.toMap());
      } else {
        _supabase.syncRecord('items', item.id, 'insert', item.toMap());
      }
      return true;
    } catch (e) {
      _error = 'Failed to add item: $e';
      debugPrint('❌ $_error');
      notifyListeners();
      return false;
    }
  }

  /// Update an item with optimistic locking.
  /// Increments the version field; fails if another device changed the item
  /// since this copy was loaded (version mismatch → conflict).
  Future<bool> updateItem(ItemModel item, {String? userRole}) async {
    // Backend RBAC guard
    if (userRole != null && !PermissionHelper(userRole).canEditInventory) {
      _error = 'Access denied: Staff cannot edit inventory.';
      debugPrint('🔒 RBAC BLOCKED: $userRole tried to update item ${item.id}');
      notifyListeners();
      return false;
    }
    try {
      final updated = item.copyWith(
        version: item.version + 1,
        updatedAt: DateTime.now(),
      );
      final rowsAffected = await _db.updateWithVersion(
        'items', updated.toMap(), updated.id, item.version,
      );

      if (rowsAffected == 0) {
        // Version conflict — another device updated this item
        _error = 'Conflict: This item was modified on another device. Please refresh and try again.';
        debugPrint('⚠️ OPTIMISTIC LOCK CONFLICT: item ${item.id} version ${item.version} is stale');
        // Reload the item from DB to get fresh data
        await _reloadItem(item.id);
        notifyListeners();
        return false;
      }

      final index = _items.indexWhere((i) => i.id == updated.id);
      if (index != -1) {
        _items[index] = updated;
        _applySearch();
      }
      notifyListeners();

      if (kIsWeb) {
        await _supabase.syncRecord('items', updated.id, 'update', updated.toMap());
      } else {
        _supabase.syncRecord('items', updated.id, 'update', updated.toMap());
      }
      return true;
    } catch (e) {
      _error = 'Failed to update item: $e';
      notifyListeners();
      return false;
    }
  }

  /// Reload a single item from DB to get fresh version after a conflict
  Future<void> _reloadItem(String id) async {
    try {
      final map = await _db.getById('items', id);
      if (map != null) {
        final fresh = ItemModel.fromMap(map);
        final index = _items.indexWhere((i) => i.id == id);
        if (index != -1) _items[index] = fresh;
      }
    } catch (e) {
      debugPrint('Failed to reload item $id: $e');
    }
  }

  Future<bool> deleteItem(String id, {String? userRole}) async {
    // Backend RBAC guard
    if (userRole != null && !PermissionHelper(userRole).canDeleteInventory) {
      _error = 'Access denied: Staff cannot delete inventory.';
      debugPrint('🔒 RBAC BLOCKED: $userRole tried to delete item $id');
      notifyListeners();
      return false;
    }
    try {
      await _db.softDelete('items', id);
      final item = _items.firstWhere((i) => i.id == id);

      _items.removeWhere((i) => i.id == id);
      _applySearch();
      notifyListeners();

      if (kIsWeb) {
        await _supabase.syncRecord('items', id, 'delete', item.toMap());
      } else {
        _supabase.syncRecord('items', id, 'delete', item.toMap());
      }
      return true;
    } catch (e) {
      _error = 'Failed to delete item: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> updateStock(String id, int newQuantity) async {
    final item = _items.firstWhere((i) => i.id == id);
    await updateItem(item.copyWith(quantity: newQuantity));
  }

  /// Deduct stock for sold items — reads fresh version from DB to prevent conflicts
  Future<void> deductStock(String itemId, int quantity) async {
    try {
      // Re-read from DB for freshest version (critical for concurrent sales)
      final map = await _db.getById('items', itemId);
      if (map == null) {
        debugPrint('Stock deduction failed: item $itemId not found in DB');
        return;
      }
      final fresh = ItemModel.fromMap(map);
      final newQty = (fresh.quantity - quantity).clamp(0, 999999);
      final success = await updateItem(fresh.copyWith(quantity: newQty));
      if (!success && _error.contains('Conflict')) {
        // Retry once with re-read
        debugPrint('🔄 Retrying stock deduction for $itemId after conflict...');
        final retryMap = await _db.getById('items', itemId);
        if (retryMap != null) {
          final retryItem = ItemModel.fromMap(retryMap);
          final retryQty = (retryItem.quantity - quantity).clamp(0, 999999);
          await updateItem(retryItem.copyWith(quantity: retryQty));
        }
      }
    } catch (e) {
      debugPrint('Stock deduction failed for $itemId: $e');
    }
  }

  /// Restock items for returns — reads fresh version from DB to prevent conflicts
  Future<void> restockItem(String itemId, int quantity) async {
    try {
      // Re-read from DB for freshest version
      final map = await _db.getById('items', itemId);
      if (map == null) {
        debugPrint('Restock failed: item $itemId not found in DB');
        return;
      }
      final fresh = ItemModel.fromMap(map);
      final newQty = fresh.quantity + quantity;
      final success = await updateItem(fresh.copyWith(quantity: newQty));
      if (!success && _error.contains('Conflict')) {
        // Retry once with re-read
        debugPrint('🔄 Retrying restock for $itemId after conflict...');
        final retryMap = await _db.getById('items', itemId);
        if (retryMap != null) {
          final retryItem = ItemModel.fromMap(retryMap);
          final retryQty = retryItem.quantity + quantity;
          await updateItem(retryItem.copyWith(quantity: retryQty));
        }
      }
    } catch (e) {
      debugPrint('Restock failed for $itemId: $e');
    }
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }
}
