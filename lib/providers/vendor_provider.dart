import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/local/db_helper.dart';
import '../data/remote/supabase_service.dart';
import '../data/models/vendor_model.dart';

class VendorProvider extends ChangeNotifier {
  final DBHelper _db = DBHelper.instance;
  final SupabaseService _supabase = SupabaseService.instance;
  final _uuid = const Uuid();

  List<VendorModel> _vendors = [];
  bool _isLoading = false;

  List<VendorModel> get vendors => _vendors;
  bool get isLoading => _isLoading;

  /// Load all active vendors from local DB
  Future<void> loadVendors() async {
    _isLoading = true;
    notifyListeners();

    try {
      final maps = await _db.query(
        'vendors',
        where: 'is_deleted = 0',
        orderBy: 'name ASC',
      );
      _vendors = maps.map((m) => VendorModel.fromMap(m)).toList();
      debugPrint('📋 VendorProvider: loaded ${_vendors.length} vendors from DB');
    } catch (e) {
      debugPrint('❌ Failed to load vendors: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Add a new vendor — saves to Supabase FIRST on web, then local cache
  Future<bool> addVendor({
    required String name,
    String phone = '',
    String notes = '',
  }) async {
    try {
      final vendor = VendorModel(
        id: _uuid.v4(),
        name: name,
        phone: phone,
        notes: notes,
      );

      debugPrint('➕ VendorProvider: adding vendor "${vendor.name}" (${vendor.id})');

      // STEP 1: Save to local DB (in-memory on web)
      await _db.insert('vendors', vendor.toMap());
      debugPrint('   ✓ Saved to local DB');

      // STEP 2: Add to in-memory list immediately (UI updates)
      _vendors.add(vendor);
      _vendors.sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
      debugPrint('   ✓ Added to provider list (total: ${_vendors.length})');

      // STEP 3: Sync to Supabase (await on web for persistence!)
      if (kIsWeb) {
        final synced = await _supabase.syncRecord('vendors', vendor.id, 'insert', vendor.toMap());
        if (synced) {
          debugPrint('   ✓ Synced to Supabase');
        } else {
          debugPrint('   ⚠️ Supabase sync queued (will retry)');
        }
      } else {
        // On mobile, fire-and-forget (SQLite is persistent)
        _supabase.syncRecord('vendors', vendor.id, 'insert', vendor.toMap());
      }

      return true;
    } catch (e) {
      debugPrint('❌ Failed to add vendor: $e');
      return false;
    }
  }

  /// Update an existing vendor
  Future<bool> updateVendor(VendorModel vendor) async {
    try {
      final updated = vendor.copyWith(updatedAt: DateTime.now());
      
      // Save to local DB
      await _db.update('vendors', updated.toMap(), updated.id);
      
      // Update in-memory list
      final idx = _vendors.indexWhere((v) => v.id == updated.id);
      if (idx != -1) _vendors[idx] = updated;
      notifyListeners();

      // Sync to Supabase
      if (kIsWeb) {
        await _supabase.syncRecord('vendors', updated.id, 'update', updated.toMap());
      } else {
        _supabase.syncRecord('vendors', updated.id, 'update', updated.toMap());
      }
      return true;
    } catch (e) {
      debugPrint('❌ Failed to update vendor: $e');
      return false;
    }
  }

  /// Soft-delete a vendor
  Future<bool> deleteVendor(String id) async {
    try {
      final vendor = _vendors.firstWhere((v) => v.id == id);
      final deleted = vendor.copyWith(isDeleted: true);
      await _db.update('vendors', deleted.toMap(), deleted.id);

      _vendors.removeWhere((v) => v.id == id);
      notifyListeners();

      if (kIsWeb) {
        await _supabase.syncRecord('vendors', deleted.id, 'delete', deleted.toMap());
      } else {
        _supabase.syncRecord('vendors', deleted.id, 'delete', deleted.toMap());
      }
      return true;
    } catch (e) {
      debugPrint('❌ Failed to delete vendor: $e');
      return false;
    }
  }

  /// Adjust vendor balance (e.g., after purchase payment)
  Future<bool> adjustBalance(String vendorId, double amount) async {
    try {
      final idx = _vendors.indexWhere((v) => v.id == vendorId);
      if (idx == -1) return false;

      final updated = _vendors[idx].copyWith(
        balance: _vendors[idx].balance + amount,
      );
      await _db.update('vendors', updated.toMap(), updated.id);

      _vendors[idx] = updated;
      notifyListeners();

      if (kIsWeb) {
        await _supabase.syncRecord('vendors', updated.id, 'update', updated.toMap());
      } else {
        _supabase.syncRecord('vendors', updated.id, 'update', updated.toMap());
      }
      return true;
    } catch (e) {
      debugPrint('❌ Failed to adjust vendor balance: $e');
      return false;
    }
  }

  /// Get vendor by ID
  VendorModel? getVendor(String id) {
    try {
      return _vendors.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }
}
