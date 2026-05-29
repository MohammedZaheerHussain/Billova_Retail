import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../local/db_helper.dart';

/// Handles all Supabase operations: auth + cloud backup sync.
///
/// Sync Rules:
/// - On login → pull all user data from Supabase → store in SQLite
/// - On create/update/delete → save locally first, then sync to Supabase
/// - If sync fails → add to sync_queue, retry later
/// - Conflict resolution: latest updated_at wins
class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;
  DBHelper get _db => DBHelper.instance;

  // ─── Auth ───

  User? get currentUser => _client.auth.currentUser;
  String? get userId => currentUser?.id;
  bool get isLoggedIn => currentUser != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp(String email, String password) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<Session?> recoverSession() async {
    try {
      final session = _client.auth.currentSession;
      return session;
    } catch (e) {
      debugPrint('Session recovery failed: $e');
      return null;
    }
  }

  // ─── Full Sync (on login) ───

  Future<void> pullAllData() async {
    if (!isLoggedIn) return;

    try {
      // Sync priority order: items first, then dependent tables
      await pullTable('items');
      await pullTable('sales');
      await pullTable('purchases');
      await pullTable('expenses');
      await pullTable('vendors');
      await pullTable('staff');
      await pullTable('attendance');
      await pullTable('customers');
      await pullTable('cash_till');
      await pullTable('categories');
      await pullTable('clearance_items');
      await pullTable('loyalty_transactions');
      await pullTable('revenue_snapshots');
      debugPrint('✅ Full data pull complete');
    } catch (e) {
      debugPrint('⚠️ Data pull had errors (non-fatal): $e');
      // Don't rethrow — sync errors should never crash the app
    }
  }

  Future<void> pullTable(String table) async {
    try {
      // Tables without updated_at — order by created_at instead
      const noUpdatedAt = {'attendance', 'loyalty_transactions'};
      final orderCol = noUpdatedAt.contains(table) ? 'created_at' : 'updated_at';

      // All tables now have user_id — filter by current user for data isolation
      var query = _client.from(table).select();
      query = query.eq('user_id', userId!);
      final data = await query.order(orderCol);

      if (data.isNotEmpty) {
        // Convert Supabase records to local SQLite format
        final localRecords = data.map((record) {
          final local = Map<String, dynamic>.from(record);
          local.remove('user_id'); // Don't store user_id locally
          // Convert boolean to integer for SQLite
          if (local.containsKey('is_deleted')) {
            local['is_deleted'] = local['is_deleted'] == true ? 1 : 0;
          }
          if (local.containsKey('is_active')) {
            local['is_active'] = local['is_active'] == true ? 1 : 0;
          }
          // Convert JSONB list to TEXT for SQLite (sales.items)
          if (local.containsKey('items') && local['items'] is List) {
            local['items'] = jsonEncode(local['items']);
          }
          return local;
        }).toList();

        await _db.upsertAll(table, localRecords);
        debugPrint('  ✓ Pulled ${localRecords.length} records for $table');
      } else {
        debugPrint('  ○ No records for $table');
      }
    } catch (e) {
      debugPrint('  ✗ Failed to pull $table: $e');
    }
  }

  // ─── Sync to Cloud ───

  /// CRITICAL TABLES: Save to Supabase FIRST. Throws on failure.
  /// Use for sales, customers — data loss is unacceptable.
  /// Does NOT fall back to sync queue — caller must handle failure.
  Future<void> guaranteedSave(String table, Map<String, dynamic> data) async {
    if (!isLoggedIn) {
      throw Exception('Not logged in — cannot save to cloud');
    }

    final cloudData = Map<String, dynamic>.from(data);
    cloudData['user_id'] = userId;
    // Convert SQLite integer back to boolean
    if (cloudData.containsKey('is_deleted')) {
      cloudData['is_deleted'] = cloudData['is_deleted'] == 1;
    }
    // Convert TEXT items back to JSONB list for Supabase
    if (cloudData.containsKey('items') && cloudData['items'] is String) {
      try {
        cloudData['items'] = jsonDecode(cloudData['items'] as String);
      } catch (_) {}
    }

    // This MUST succeed — throws on failure
    await _client.from(table).upsert(cloudData);
    debugPrint('☁️ GUARANTEED save to $table/${data['id']}');
  }

  /// Push a single record to Supabase. If it fails, add to sync queue.
  /// Use for NON-CRITICAL data (expenses, attendance, cash_till, etc.)
  Future<bool> syncRecord(String table, String recordId, String action, Map<String, dynamic> data) async {
    if (!isLoggedIn) {
      await _queueSync(table, recordId, action, data);
      return false;
    }

    try {
      final cloudData = Map<String, dynamic>.from(data);
      cloudData['user_id'] = userId;
      // Convert SQLite integer back to boolean
      if (cloudData.containsKey('is_deleted')) {
        cloudData['is_deleted'] = cloudData['is_deleted'] == 1;
      }
      // Convert TEXT items back to JSONB list for Supabase
      if (cloudData.containsKey('items') && cloudData['items'] is String) {
        try {
          cloudData['items'] = jsonDecode(cloudData['items'] as String);
        } catch (_) {}
      }
      // Strip local-only columns that don't exist in Supabase schema.
      // These cause PGRST204 errors and block sync entirely.
      _stripLocalOnlyColumns(table, cloudData);

      switch (action) {
        case 'insert':
          await _client.from(table).upsert(cloudData);
          break;
        case 'update':
          await _client.from(table).upsert(cloudData);
          break;
        case 'delete':
          // Soft delete — update is_deleted flag in cloud
          await _client.from(table).update({
            'is_deleted': true,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', recordId);
          break;
      }

      debugPrint('☁️ Synced $action on $table/$recordId');
      return true;
    } catch (e) {
      debugPrint('☁️ Sync failed for $table/$recordId: $e');
      await _queueSync(table, recordId, action, data);
      return false;
    }
  }

  /// Remove columns that exist locally but NOT in Supabase schema.
  /// Without this, upsert fails with PGRST204 and data never syncs.
  static void _stripLocalOnlyColumns(String table, Map<String, dynamic> data) {
    const localOnlyColumns = <String, List<String>>{
      'expenses': ['payment_mode'],
      'cash_till': ['actual_closing_cash'],
    };
    final cols = localOnlyColumns[table];
    if (cols != null) {
      for (final col in cols) {
        data.remove(col);
      }
    }
  }

  Future<void> _queueSync(String table, String recordId, String action, Map<String, dynamic> data) async {
    await _db.addToSyncQueue(table, recordId, action, jsonEncode(data));
  }

  // ─── Process Sync Queue (retry failed syncs) ───

  Future<int> processSyncQueue() async {
    if (!isLoggedIn) return 0;

    final pendingItems = await _db.getPendingSyncItems();
    int syncedCount = 0;

    for (final item in pendingItems) {
      if ((item['retry_count'] as int) >= 5) {
        // Too many retries, remove from queue
        await _db.removeSyncItem(item['id'] as int);
        continue;
      }

      try {
        final data = jsonDecode(item['payload'] as String) as Map<String, dynamic>;
        final cloudData = Map<String, dynamic>.from(data);
        cloudData['user_id'] = userId;

        if (cloudData.containsKey('is_deleted')) {
          cloudData['is_deleted'] = cloudData['is_deleted'] == 1;
        }

        final action = item['action'] as String;
        final table = item['table_name'] as String;

        // Strip local-only columns on retry too
        _stripLocalOnlyColumns(table, cloudData);

        if (action == 'delete') {
          await _client.from(table).update({
            'is_deleted': true,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', item['record_id']);
        } else {
          await _client.from(table).upsert(cloudData);
        }

        await _db.removeSyncItem(item['id'] as int);
        syncedCount++;
      } catch (e) {
        await _db.incrementSyncRetry(item['id'] as int);
        debugPrint('Retry failed for sync item ${item['id']}: $e');
      }
    }

    if (syncedCount > 0) {
      debugPrint('☁️ Processed $syncedCount sync queue items');
    }

    return syncedCount;
  }

  // ─── Conflict Resolution ───

  /// Compare local vs cloud updated_at → latest wins
  Future<Map<String, dynamic>> resolveConflict(
    Map<String, dynamic> local,
    Map<String, dynamic> cloud,
  ) async {
    final localUpdated = DateTime.parse(local['updated_at'] as String);
    final cloudUpdated = DateTime.parse(cloud['updated_at'] as String);

    return cloudUpdated.isAfter(localUpdated) ? cloud : local;
  }
}
