import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';

/// In-memory database implementation for web platform.
/// All data is stored in Dart Maps. Supabase handles cloud persistence.
/// CRITICAL: sync_queue is persisted to localStorage to survive page refreshes.
class _WebDB {
  final Map<String, List<Map<String, dynamic>>> _tables = {};
  bool _initialized = false;

  /// Key used to persist sync queue in localStorage (via SharedPreferences)
  static const _syncQueueKey = 'skywalk_sync_queue';

  Future<void> init() async {
    if (_initialized) return;
    _tables['items'] = [];
    _tables['sales'] = [];
    _tables['expenses'] = [];
    _tables['cash_till'] = [];
    _tables['vendors'] = [];
    _tables['purchases'] = [];
    _tables['staff'] = [];
    _tables['attendance'] = [];
    _tables['customers'] = [];
    _tables['settings'] = [
      {'key': 'last_invoice_number', 'value': '0'},
    ];
    _tables['categories'] = [];
    _tables['sync_queue'] = [];
    _tables['loyalty_transactions'] = [];
    _tables['clearance_items'] = [];
    _tables['revenue_snapshots'] = [];
    _tables['returns'] = [];
    _initialized = true;

    // ─── CRITICAL: Restore sync queue from localStorage ───
    // On web, in-memory DB is wiped on every page refresh.
    // Sync queue items (failed syncs) MUST survive refreshes
    // or data created offline/during failures is lost forever.
    await _restoreSyncQueueFromStorage();
  }

  /// Restore sync queue from localStorage after page refresh
  Future<void> _restoreSyncQueueFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_syncQueueKey);
      if (stored != null && stored.isNotEmpty) {
        final List<dynamic> items = _jsonDecode(stored);
        final queue = _getTable('sync_queue');
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            // Avoid duplicates
            final exists = queue.any((q) => q['id'] == item['id']);
            if (!exists) {
              queue.add(Map<String, dynamic>.from(item));
            }
          }
        }
        debugPrint('🔄 Restored ${items.length} sync queue items from localStorage');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to restore sync queue from localStorage: $e');
    }
  }

  /// Persist current sync queue to localStorage (call after every modification)
  Future<void> _persistSyncQueueToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = _getTable('sync_queue');
      if (queue.isEmpty) {
        await prefs.remove(_syncQueueKey);
      } else {
        await prefs.setString(_syncQueueKey, _jsonEncode(queue));
      }
    } catch (e) {
      debugPrint('⚠️ Failed to persist sync queue to localStorage: $e');
    }
  }

  /// Clear sync queue from localStorage (only on full sign out)
  Future<void> clearSyncQueueStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_syncQueueKey);
    } catch (_) {}
  }

  /// Safe JSON encode/decode helpers
  static String _jsonEncode(Object obj) {
    try {
      return const JsonEncoder().convert(obj);
    } catch (_) {
      return '[]';
    }
  }

  static List<dynamic> _jsonDecode(String str) {
    try {
      final result = const JsonDecoder().convert(str);
      return result is List ? result : [];
    } catch (_) {
      return [];
    }
  }

  /// CRITICAL: Must always return a reference stored in _tables.
  /// If the table doesn't exist, create it and store in _tables FIRST.
  List<Map<String, dynamic>> _getTable(String name) {
    if (!_tables.containsKey(name)) {
      _tables[name] = [];
    }
    return _tables[name]!;
  }

  Future<int> insert(String table, Map<String, dynamic> data, {ConflictAlgorithm? conflictAlgorithm}) async {
    final rows = _getTable(table);
    final dataId = data['id'];
    final dataKey = data['key'];
    final existing = rows.indexWhere((r) => 
      (dataId != null && r['id'] == dataId) || 
      (dataKey != null && r['key'] == dataKey));
    if (existing != -1) {
      rows[existing] = Map<String, dynamic>.from(data);
    } else {
      rows.add(Map<String, dynamic>.from(data));
    }
    return 1;
  }

  Future<int> update(String table, Map<String, dynamic> data, {String? where, List<dynamic>? whereArgs}) async {
    final rows = _getTable(table);
    int count = 0;
    for (int i = 0; i < rows.length; i++) {
      if (_matchesWhere(rows[i], where, whereArgs)) {
        rows[i] = {...rows[i], ...data};
        count++;
      }
    }
    return count;
  }

  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    final rows = _getTable(table);
    if (where == null) {
      final count = rows.length;
      rows.clear();
      return count;
    }
    final before = rows.length;
    rows.removeWhere((r) => _matchesWhere(r, where, whereArgs));
    return before - rows.length;
  }

  Future<List<Map<String, dynamic>>> query(String table, {
    String? where, List<dynamic>? whereArgs, String? orderBy, int? limit,
  }) async {
    var rows = _getTable(table)
        .where((r) => _matchesWhere(r, where, whereArgs))
        .map((r) => Map<String, dynamic>.from(r))
        .toList();

    if (orderBy != null) {
      // Support multi-column: "date DESC, clock_in_time DESC"
      final sortCols = orderBy.split(',').map((s) => s.trim()).toList();
      rows.sort((a, b) {
        for (final sortExpr in sortCols) {
          final parts = sortExpr.split(' ');
          final col = parts[0];
          final desc = parts.length > 1 && parts[1].toUpperCase() == 'DESC';
          final va = a[col];
          final vb = b[col];
          if (va == null && vb == null) continue;
          if (va == null) return desc ? 1 : -1;
          if (vb == null) return desc ? -1 : 1;
          final cmp = Comparable.compare(va as Comparable, vb as Comparable);
          if (cmp != 0) return desc ? -cmp : cmp;
        }
        return 0;
      });
    }

    if (limit != null) rows = rows.take(limit).toList();
    return rows;
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? args]) async {
    // Handle specific dashboard queries
    if (sql.contains('COUNT(*)')) {
      return [{'count': 0}];
    }
    if (sql.contains('SUM(')) {
      return [{'total': 0.0}];
    }
    if (sql.contains('GROUP BY')) {
      return [];
    }
    return [];
  }

  Future<int> rawUpdate(String sql, [List<dynamic>? args]) async => 0;

  bool _matchesWhere(Map<String, dynamic> row, String? where, List<dynamic>? args) {
    if (where == null) return true;

    // Parse simple conditions: "col = ?", "col LIKE ?", "col >= ?", "col <= ?"
    final conditions = where.split(' AND ');
    int argIdx = 0;

    for (final cond in conditions) {
      final trimmed = cond.trim();

      if (trimmed.contains(' LIKE ')) {
        final parts = trimmed.split(' LIKE ');
        final col = parts[0].trim();
        if (args != null && argIdx < args.length) {
          final pattern = args[argIdx].toString().replaceAll('%', '');
          final val = row[col]?.toString() ?? '';
          if (!val.contains(pattern)) return false;
          argIdx++;
        }
      } else if (trimmed.contains(' >= ')) {
        final parts = trimmed.split(' >= ');
        final col = parts[0].trim();
        if (parts[1].trim() == '?') {
          // Parameterized: compare row[col] >= args[argIdx] (string or num)
          if (args != null && argIdx < args.length) {
            final rowVal = row[col];
            final argVal = args[argIdx];
            if (rowVal is num && argVal is num) {
              if (rowVal < argVal) return false;
            } else {
              // String comparison (dates, etc.)
              if (rowVal.toString().compareTo(argVal.toString()) < 0) return false;
            }
            argIdx++;
          }
        } else {
          // Column-to-column or literal
          final otherCol = parts[1].trim();
          final v1 = row[col];
          final v2 = row[otherCol] ?? num.tryParse(otherCol);
          if (v1 is num && v2 is num) {
            if (v1 < v2) return false;
          }
        }
      } else if (trimmed.contains(' <= ')) {
        final parts = trimmed.split(' <= ');
        final col = parts[0].trim();
        if (parts[1].trim() == '?') {
          // Parameterized: compare row[col] <= args[argIdx] (string or num)
          if (args != null && argIdx < args.length) {
            final rowVal = row[col];
            final argVal = args[argIdx];
            if (rowVal is num && argVal is num) {
              if (rowVal > argVal) return false;
            } else {
              // String comparison (dates, etc.)
              if (rowVal.toString().compareTo(argVal.toString()) > 0) return false;
            }
            argIdx++;
          }
        } else {
          // Column-to-column comparison (e.g., quantity <= low_stock_threshold)
          final otherCol = parts[1].trim();
          final v1 = row[col];
          final v2 = row[otherCol];
          if (v1 is num && v2 is num) {
            if (v1 > v2) return false;
          }
        }
      } else if (trimmed.contains(' = ')) {
        final parts = trimmed.split(' = ');
        final col = parts[0].trim();
        if (parts[1].trim() == '?') {
          if (args != null && argIdx < args.length) {
            if (row[col] != args[argIdx] && row[col]?.toString() != args[argIdx]?.toString()) return false;
            argIdx++;
          }
        } else {
          // Literal value comparison
          final litVal = parts[1].trim();
          if (litVal == '0') {
            if (row[col] != 0 && row[col] != false) return false;
          }
        }
      } else if (trimmed.contains(' > ')) {
        final parts = trimmed.split(' > ');
        final col = parts[0].trim();
        final val = num.tryParse(parts[1].trim()) ?? 0;
        if (((row[col] as num?) ?? 0) <= val) return false;
      }
    }
    return true;
  }
}

class DBHelper {
  static Database? _database;
  static _WebDB? _webDB;
  static final DBHelper instance = DBHelper._init();

  DBHelper._init();

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('Use web-specific methods');
    }
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<_WebDB> get _web async {
    _webDB ??= _WebDB();
    await _webDB!.init();
    return _webDB!;
  }

  Future<Database> _initDB() async {
    final dbDir = await getDatabasesPath();
    final path = p.join(dbDir, AppConstants.dbName);
    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ─── Items Table ───
    await db.execute('''
      CREATE TABLE items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        vendor TEXT DEFAULT '',
        barcode TEXT DEFAULT '',
        category TEXT DEFAULT '',
        size TEXT DEFAULT '',
        color TEXT DEFAULT '',
        storage_location TEXT DEFAULT '',
        price REAL NOT NULL DEFAULT 0,
        cost_price REAL DEFAULT 0,
        quantity INTEGER DEFAULT 0,
        low_stock_threshold INTEGER DEFAULT ${AppConstants.lowStockThreshold},
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ─── Sales Table ───
    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        invoice_number TEXT NOT NULL,
        customer_name TEXT DEFAULT '',
        customer_phone TEXT DEFAULT '',
        items TEXT NOT NULL,
        subtotal REAL NOT NULL DEFAULT 0,
        discount REAL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        gst_amount REAL DEFAULT 0,
        cgst REAL DEFAULT 0,
        sgst REAL DEFAULT 0,
        payment_mode TEXT DEFAULT 'Cash',
        cash_amount REAL DEFAULT 0,
        upi_amount REAL DEFAULT 0,
        card_amount REAL DEFAULT 0,
        staff_id TEXT DEFAULT '',
        staff_name TEXT DEFAULT '',
        loyalty_discount REAL DEFAULT 0,
        points_redeemed INTEGER DEFAULT 0,
        points_earned INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ─── Expenses Table ───
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL DEFAULT 0,
        note TEXT DEFAULT '',
        category TEXT DEFAULT 'General',
        payment_mode TEXT DEFAULT 'Cash',
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ─── Cash Till Table ───
    await db.execute('''
      CREATE TABLE cash_till (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL UNIQUE,
        opening_cash REAL DEFAULT 0,
        actual_closing_cash REAL DEFAULT -1,
        notes TEXT DEFAULT '',
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ─── Settings Table ───
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.insert('settings', {
      'key': 'last_invoice_number',
      'value': '0',
    });

    // ─── Categories Table ───
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        requires_size INTEGER DEFAULT 0,
        requires_color INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ─── Sync Queue ───
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    // ─── Indexes ───
    await db.execute('CREATE INDEX idx_items_deleted ON items(is_deleted)');
    await db.execute('CREATE INDEX idx_sales_deleted ON sales(is_deleted)');
    await db.execute('CREATE INDEX idx_sales_created ON sales(created_at)');
    await db.execute('CREATE INDEX idx_expenses_deleted ON expenses(is_deleted)');
    await db.execute('CREATE INDEX idx_expenses_created ON expenses(created_at)');
    await db.execute('CREATE INDEX idx_cash_till_date ON cash_till(date)');
    await db.execute('CREATE INDEX idx_sync_queue_table ON sync_queue(table_name)');

    // ─── Vendors Table ───
    await db.execute('''
      CREATE TABLE vendors (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT DEFAULT '',
        balance REAL DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ─── Purchases Table ───
    await db.execute('''
      CREATE TABLE purchases (
        id TEXT PRIMARY KEY,
        vendor_id TEXT NOT NULL,
        vendor_name TEXT DEFAULT '',
        items TEXT NOT NULL,
        total_amount REAL NOT NULL DEFAULT 0,
        paid_amount REAL DEFAULT 0,
        payment_mode TEXT DEFAULT 'Cash',
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_vendors_deleted ON vendors(is_deleted)');
    await db.execute('CREATE INDEX idx_purchases_deleted ON purchases(is_deleted)');
    await db.execute('CREATE INDEX idx_purchases_created ON purchases(created_at)');

    // ─── Staff Table ───
    await db.execute('''
      CREATE TABLE staff (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        name TEXT NOT NULL,
        pin TEXT NOT NULL,
        role TEXT DEFAULT 'staff',
        is_active INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ─── Attendance Table ───
    await db.execute('''
      CREATE TABLE attendance (
        id TEXT PRIMARY KEY,
        staff_id TEXT NOT NULL,
        staff_name TEXT DEFAULT '',
        clock_in_time TEXT NOT NULL,
        clock_out_time TEXT DEFAULT '',
        total_hours REAL DEFAULT 0,
        date TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_staff_deleted ON staff(is_deleted)');
    await db.execute('CREATE INDEX idx_attendance_date ON attendance(date)');
    await db.execute('CREATE INDEX idx_attendance_staff ON attendance(staff_id)');

    // ─── Customers Table ───
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT DEFAULT '',
        total_orders INTEGER DEFAULT 0,
        total_spent REAL DEFAULT 0,
        loyalty_points INTEGER DEFAULT 0,
        last_purchase_date TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_customers_deleted ON customers(is_deleted)');
    await db.execute('CREATE INDEX idx_customers_phone ON customers(phone)');

    // ─── Loyalty Transactions Table ───
    await db.execute('''
      CREATE TABLE loyalty_transactions (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        type TEXT NOT NULL,
        points INTEGER NOT NULL,
        sale_id TEXT DEFAULT '',
        balance_after INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_loyalty_tx_customer ON loyalty_transactions(customer_id)');

    // ─── Returns & Exchange Audit Trail ───
    await db.execute('''
      CREATE TABLE returns (
        id TEXT PRIMARY KEY,
        original_sale_id TEXT NOT NULL,
        original_invoice TEXT NOT NULL DEFAULT '',
        type TEXT NOT NULL DEFAULT 'return',
        returned_items TEXT NOT NULL DEFAULT '[]',
        exchange_items TEXT NOT NULL DEFAULT '[]',
        refund_amount REAL NOT NULL DEFAULT 0,
        exchange_total REAL NOT NULL DEFAULT 0,
        net_settlement REAL NOT NULL DEFAULT 0,
        refund_method TEXT NOT NULL DEFAULT 'Cash',
        reason TEXT NOT NULL DEFAULT '',
        customer_name TEXT NOT NULL DEFAULT '',
        customer_phone TEXT NOT NULL DEFAULT '',
        staff_id TEXT NOT NULL DEFAULT '',
        staff_name TEXT NOT NULL DEFAULT '',
        points_reversed INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_returns_sale_id ON returns(original_sale_id)');
    await db.execute('CREATE INDEX idx_returns_created ON returns(created_at)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v2: Add vendor column to items
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE items ADD COLUMN vendor TEXT DEFAULT ''");
    }
    // v3: Add vendors + purchases tables
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS vendors (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phone TEXT DEFAULT '',
          balance REAL DEFAULT 0,
          is_deleted INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchases (
          id TEXT PRIMARY KEY,
          vendor_id TEXT NOT NULL,
          vendor_name TEXT DEFAULT '',
          items TEXT NOT NULL,
          total_amount REAL NOT NULL DEFAULT 0,
          paid_amount REAL DEFAULT 0,
          payment_mode TEXT DEFAULT 'Cash',
          is_deleted INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }
    // v4: Add staff + attendance tables
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS staff (
          id TEXT PRIMARY KEY,
          username TEXT NOT NULL,
          name TEXT NOT NULL,
          pin TEXT NOT NULL,
          role TEXT DEFAULT 'staff',
          is_active INTEGER DEFAULT 1,
          is_deleted INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS attendance (
          id TEXT PRIMARY KEY,
          staff_id TEXT NOT NULL,
          staff_name TEXT DEFAULT '',
          clock_in_time TEXT NOT NULL,
          clock_out_time TEXT DEFAULT '',
          total_hours REAL DEFAULT 0,
          date TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
      // Also add staff columns to sales table
      await db.execute("ALTER TABLE sales ADD COLUMN staff_id TEXT DEFAULT ''");
      await db.execute("ALTER TABLE sales ADD COLUMN staff_name TEXT DEFAULT ''");
    }
    // v5: Add customers table
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS customers (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phone TEXT DEFAULT '',
          total_orders INTEGER DEFAULT 0,
          total_spent REAL DEFAULT 0,
          is_deleted INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }
    // v6: Add extended item fields
    if (oldVersion < 6) {
      await db.execute("ALTER TABLE items ADD COLUMN barcode TEXT DEFAULT ''");
      await db.execute("ALTER TABLE items ADD COLUMN category TEXT DEFAULT ''");
      await db.execute("ALTER TABLE items ADD COLUMN size TEXT DEFAULT ''");
      await db.execute("ALTER TABLE items ADD COLUMN color TEXT DEFAULT ''");
      await db.execute("ALTER TABLE items ADD COLUMN storage_location TEXT DEFAULT ''");
    }
    // v7: Add loyalty_points + last_purchase_date to customers
    if (oldVersion < 7) {
      try {
        await db.execute("ALTER TABLE customers ADD COLUMN loyalty_points INTEGER DEFAULT 0");
        await db.execute("ALTER TABLE customers ADD COLUMN last_purchase_date TEXT");
      } catch (_) {} // Column may already exist
    }
    // v8: Add loyalty tracking fields to sales + audit trail table
    if (oldVersion < 8) {
      try {
        await db.execute("ALTER TABLE sales ADD COLUMN loyalty_discount REAL DEFAULT 0");
        await db.execute("ALTER TABLE sales ADD COLUMN points_redeemed INTEGER DEFAULT 0");
        await db.execute("ALTER TABLE sales ADD COLUMN points_earned INTEGER DEFAULT 0");
      } catch (_) {} // Columns may already exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS loyalty_transactions (
          id TEXT PRIMARY KEY,
          customer_id TEXT NOT NULL,
          type TEXT NOT NULL,
          points INTEGER NOT NULL,
          sale_id TEXT DEFAULT '',
          balance_after INTEGER DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_loyalty_tx_customer ON loyalty_transactions(customer_id)');

    // ─── Revenue Snapshots Table (monthly revenue persistence) ───
    await db.execute('''
      CREATE TABLE revenue_snapshots (
        id TEXT PRIMARY KEY,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        total_revenue REAL DEFAULT 0,
        total_profit REAL DEFAULT 0,
        total_discounts REAL DEFAULT 0,
        total_cogs REAL DEFAULT 0,
        total_expenses REAL DEFAULT 0,
        net_profit REAL DEFAULT 0,
        sales_count INTEGER DEFAULT 0,
        category_revenue TEXT DEFAULT '{}',
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX idx_snapshot_year_month ON revenue_snapshots(year, month)');
    }

    // v9: Add updated_at + is_deleted to categories for sync support
    if (oldVersion < 9) {
      try {
        await db.execute("ALTER TABLE categories ADD COLUMN updated_at TEXT DEFAULT ''");
        await db.execute("ALTER TABLE categories ADD COLUMN is_deleted INTEGER DEFAULT 0");
      } catch (_) {} // Columns may already exist
    }

    // v10: Clearance stock tracking — new item fields + audit table
    if (oldVersion < 10) {
      try {
        await db.execute("ALTER TABLE items ADD COLUMN original_price REAL DEFAULT 0");
        await db.execute("ALTER TABLE items ADD COLUMN parent_item_id TEXT DEFAULT ''");
      } catch (_) {} // Columns may already exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS clearance_items (
          id TEXT PRIMARY KEY,
          original_item_id TEXT NOT NULL,
          clearance_item_id TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          original_price REAL NOT NULL,
          clearance_price REAL NOT NULL,
          reason TEXT NOT NULL DEFAULT '',
          status TEXT NOT NULL DEFAULT 'active',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_clearance_original ON clearance_items(original_item_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_clearance_status ON clearance_items(status)');
    }

    // v11: Staff monthly sale target
    if (oldVersion < 11) {
      try {
        await db.execute("ALTER TABLE staff ADD COLUMN monthly_sale_target REAL DEFAULT 0");
      } catch (_) {} // Column may already exist
    }

    // v12: Add GST columns + payment split columns to sales
    if (oldVersion < 12) {
      try {
        await db.execute("ALTER TABLE sales ADD COLUMN gst_amount REAL DEFAULT 0");
        await db.execute("ALTER TABLE sales ADD COLUMN cgst REAL DEFAULT 0");
        await db.execute("ALTER TABLE sales ADD COLUMN sgst REAL DEFAULT 0");
      } catch (_) {} // Columns may already exist
      try {
        await db.execute("ALTER TABLE sales ADD COLUMN cash_amount REAL DEFAULT 0");
        await db.execute("ALTER TABLE sales ADD COLUMN upi_amount REAL DEFAULT 0");
        await db.execute("ALTER TABLE sales ADD COLUMN card_amount REAL DEFAULT 0");
      } catch (_) {} // Columns may already exist
    }

    // v13: Add unique index on customer phone for phone-based identification
    if (oldVersion < 13) {
      try {
        // Add index on phone for fast lookups
        await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone)');
        // Add balance + gst_number columns if missing from older schemas
        await db.execute("ALTER TABLE customers ADD COLUMN balance REAL DEFAULT 0");
      } catch (_) {} // Column may already exist
      try {
        await db.execute("ALTER TABLE customers ADD COLUMN gst_number TEXT DEFAULT ''");
      } catch (_) {} // Column may already exist
    }

    // v14: Cash Till separation — expense payment mode + actual closing cash
    if (oldVersion < 14) {
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN payment_mode TEXT DEFAULT 'Cash'");
      } catch (_) {} // Column may already exist
      try {
        await db.execute("ALTER TABLE cash_till ADD COLUMN actual_closing_cash REAL DEFAULT -1");
      } catch (_) {} // Column may already exist
    }

    // v15: Revenue snapshots table — monthly revenue data persistence
    if (oldVersion < 15) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS revenue_snapshots (
          id TEXT PRIMARY KEY,
          year INTEGER NOT NULL,
          month INTEGER NOT NULL,
          total_revenue REAL DEFAULT 0,
          total_profit REAL DEFAULT 0,
          total_discounts REAL DEFAULT 0,
          total_cogs REAL DEFAULT 0,
          total_expenses REAL DEFAULT 0,
          net_profit REAL DEFAULT 0,
          sales_count INTEGER DEFAULT 0,
          category_revenue TEXT DEFAULT '{}',
          is_deleted INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      try {
        await db.execute('CREATE UNIQUE INDEX idx_snapshot_year_month ON revenue_snapshots(year, month)');
      } catch (_) {} // Index may already exist

      // Returns & Exchange audit trail (also v15)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS returns (
          id TEXT PRIMARY KEY,
          original_sale_id TEXT NOT NULL,
          original_invoice TEXT NOT NULL DEFAULT '',
          type TEXT NOT NULL DEFAULT 'return',
          returned_items TEXT NOT NULL DEFAULT '[]',
          exchange_items TEXT NOT NULL DEFAULT '[]',
          refund_amount REAL NOT NULL DEFAULT 0,
          exchange_total REAL NOT NULL DEFAULT 0,
          net_settlement REAL NOT NULL DEFAULT 0,
          refund_method TEXT NOT NULL DEFAULT 'Cash',
          reason TEXT NOT NULL DEFAULT '',
          customer_name TEXT NOT NULL DEFAULT '',
          customer_phone TEXT NOT NULL DEFAULT '',
          staff_id TEXT NOT NULL DEFAULT '',
          staff_name TEXT NOT NULL DEFAULT '',
          points_reversed INTEGER NOT NULL DEFAULT 0,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_returns_sale_id ON returns(original_sale_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_returns_created ON returns(created_at)');
    }

    // v16: Optimistic locking — add version column to items for concurrent edit protection
    if (oldVersion < 16) {
      try {
        await db.execute("ALTER TABLE items ADD COLUMN version INTEGER DEFAULT 1");
      } catch (_) {} // Column may already exist
    }
  }

  // ─── Generic CRUD ───

  Future<int> insert(String table, Map<String, dynamic> data) async {
    if (kIsWeb) {
      final web = await _web;
      return await web.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    final db = await database;
    return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(String table, Map<String, dynamic> data, String id) async {
    data['updated_at'] = DateTime.now().toUtc().toIso8601String();
    if (kIsWeb) {
      final web = await _web;
      return await web.update(table, data, where: 'id = ?', whereArgs: [id]);
    }
    final db = await database;
    return await db.update(table, data, where: 'id = ?', whereArgs: [id]);
  }

  /// Optimistic-lock update: only succeeds if the row's version matches [expectedVersion].
  /// Returns the number of rows updated (0 = version conflict, 1 = success).
  /// The caller MUST increment the version in [data] before calling this.
  Future<int> updateWithVersion(String table, Map<String, dynamic> data, String id, int expectedVersion) async {
    data['updated_at'] = DateTime.now().toUtc().toIso8601String();
    if (kIsWeb) {
      // Web uses in-memory maps — simulate version check
      final web = await _web;
      final rows = await web.query(table, where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return 0;
      final currentVersion = (rows.first['version'] as num?)?.toInt() ?? 1;
      if (currentVersion != expectedVersion) return 0; // Conflict!
      return await web.update(table, data, where: 'id = ?', whereArgs: [id]);
    }
    final db = await database;
    return await db.update(
      table,
      data,
      where: 'id = ? AND version = ?',
      whereArgs: [id, expectedVersion],
    );
  }

  Future<int> softDelete(String table, String id) async {
    final data = {
      'is_deleted': 1,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (kIsWeb) {
      final web = await _web;
      return await web.update(table, data, where: 'id = ?', whereArgs: [id]);
    }
    final db = await database;
    return await db.update(table, data, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAll(String table, {String? orderBy}) async {
    if (kIsWeb) {
      final web = await _web;
      return await web.query(table, where: 'is_deleted = 0', orderBy: orderBy ?? 'created_at DESC');
    }
    final db = await database;
    return await db.query(
      table,
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: orderBy ?? 'created_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getById(String table, String id) async {
    if (kIsWeb) {
      final web = await _web;
      final results = await web.query(table, where: 'id = ?', whereArgs: [id]);
      return results.isNotEmpty ? results.first : null;
    }
    final db = await database;
    final results = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    if (kIsWeb) {
      final web = await _web;
      return await web.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy ?? 'created_at DESC', limit: limit);
    }
    final db = await database;
    return await db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy ?? 'created_at DESC', limit: limit);
  }

  Future<int> count(String table, {String? where, List<dynamic>? whereArgs}) async {
    if (kIsWeb) {
      final web = await _web;
      final rows = await web.query(table, where: where, whereArgs: whereArgs);
      return rows.length;
    }
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $table ${where != null ? "WHERE $where" : ""}',
      whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<double> sum(String table, String column, {String? where, List<dynamic>? whereArgs}) async {
    if (kIsWeb) {
      final web = await _web;
      final rows = await web.query(table, where: where, whereArgs: whereArgs);
      double total = 0;
      for (final row in rows) {
        total += (row[column] as num?)?.toDouble() ?? 0.0;
      }
      return total;
    }
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM($column), 0) as total FROM $table ${where != null ? "WHERE $where" : ""}',
      whereArgs,
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // ─── Settings ───
  // On web, use SharedPreferences (localStorage) which survives hard refresh.
  // _WebDB is in-memory only and gets wiped on reload.

  Future<String?> getSetting(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('setting_$key');
    }
    final db = await database;
    final results = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return results.isNotEmpty ? results.first['value'] as String : null;
  }

  Future<void> setSetting(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('setting_$key', value);
      return;
    }
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ─── Invoice Number ───

  Future<String> nextInvoiceNumber() async {
    // Date in DDMMYY format (Indian-friendly)
    final now = DateTime.now();
    final dd = now.day.toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final yy = (now.year % 100).toString().padLeft(2, '0');
    final todayKey = '$dd$mm$yy'; // e.g. "300426"

    // Get stored GLOBAL sequence (never resets across days)
    final lastSeq = await getSetting('last_invoice_seq') ?? '0';
    int seq = int.parse(lastSeq) + 1;

    // Double-check: scan ALL sales for highest sequence number
    try {
      List<Map<String, dynamic>> rows;
      if (kIsWeb) {
        final web = await _web;
        rows = await web.query('sales', orderBy: 'created_at DESC');
      } else {
        final db = await database;
        rows = await db.query('sales', orderBy: 'created_at DESC');
      }
      for (final row in rows) {
        final inv = row['invoice_number'] as String? ?? '';
        if (inv.startsWith('SKY-')) {
          final parts = inv.split('-');
          if (parts.length == 3) {
            final dbSeq = int.tryParse(parts[2]) ?? 0;
            if (dbSeq >= seq) seq = dbSeq + 1;
          }
          break; // Only need the latest
        }
      }
    } catch (_) {}

    await setSetting('last_invoice_seq', seq.toString());
    return 'SKY-$todayKey-${seq.toString().padLeft(4, '0')}';
  }

  // ─── Categories CRUD ───

  Future<List<Map<String, dynamic>>> getCategories() async {
    if (kIsWeb) {
      final web = await _web;
      final rows = await web.query('categories', orderBy: 'name ASC');
      return rows.where((r) => r['is_deleted'] != 1 && r['is_deleted'] != true).toList();
    }
    final db = await database;
    return await db.query('categories', where: 'is_deleted = ?', whereArgs: [0], orderBy: 'name ASC');
  }

  Future<void> insertCategory(Map<String, dynamic> data) async {
    if (kIsWeb) {
      final web = await _web;
      await web.insert('categories', data);
      return;
    }
    final db = await database;
    await db.insert('categories', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateCategory(Map<String, dynamic> data, String id) async {
    data['updated_at'] = DateTime.now().toUtc().toIso8601String();
    if (kIsWeb) {
      final web = await _web;
      await web.update('categories', data, where: 'id = ?', whereArgs: [id]);
      return;
    }
    final db = await database;
    await db.update('categories', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteCategory(String id) async {
    // Soft delete for sync support
    final data = {
      'is_deleted': 1,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (kIsWeb) {
      final web = await _web;
      await web.update('categories', data, where: 'id = ?', whereArgs: [id]);
      return;
    }
    final db = await database;
    await db.update('categories', data, where: 'id = ?', whereArgs: [id]);
  }

  // ─── Sync Queue ───

  Future<void> addToSyncQueue(String tableName, String recordId, String action, String payload) async {
    final data = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'table_name': tableName,
      'record_id': recordId,
      'action': action,
      'payload': payload,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'retry_count': 0,
    };
    if (kIsWeb) {
      final web = await _web;
      await web.insert('sync_queue', data);
      // CRITICAL: Persist to localStorage so queue survives page refresh
      await web._persistSyncQueueToStorage();
      debugPrint('📦 Sync queue: added $action on $tableName/$recordId (persisted to localStorage)');
      return;
    }
    final db = await database;
    await db.insert('sync_queue', {
      'table_name': tableName,
      'record_id': recordId,
      'action': action,
      'payload': payload,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'retry_count': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    if (kIsWeb) {
      final web = await _web;
      return await web.query('sync_queue', orderBy: 'created_at ASC', limit: 50);
    }
    final db = await database;
    return await db.query('sync_queue', orderBy: 'created_at ASC', limit: 50);
  }

  Future<void> removeSyncItem(int id) async {
    if (kIsWeb) {
      final web = await _web;
      await web.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
      // CRITICAL: Update localStorage after removal
      await web._persistSyncQueueToStorage();
      return;
    }
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementSyncRetry(int id) async {
    if (kIsWeb) {
      // Update retry count in web in-memory DB
      final web = await _web;
      final items = await web.query('sync_queue', where: 'id = ?', whereArgs: [id]);
      if (items.isNotEmpty) {
        final current = (items.first['retry_count'] as int?) ?? 0;
        await web.update('sync_queue', {'retry_count': current + 1}, where: 'id = ?', whereArgs: [id]);
        // CRITICAL: Update localStorage after retry increment
        await web._persistSyncQueueToStorage();
      }
      return;
    }
    final db = await database;
    await db.rawUpdate('UPDATE sync_queue SET retry_count = retry_count + 1 WHERE id = ?', [id]);
  }

  /// Get count of pending sync items (for UI indicators)
  Future<int> pendingSyncCount() async {
    if (kIsWeb) {
      final web = await _web;
      final items = await web.query('sync_queue');
      return items.length;
    }
    return await count('sync_queue');
  }

  // ─── Bulk Operations (for sync) ───

  Future<void> upsertAll(String table, List<Map<String, dynamic>> records) async {
    if (kIsWeb) {
      final web = await _web;
      for (final record in records) {
        await web.insert(table, record, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      return;
    }
    final db = await database;
    final batch = db.batch();
    for (final record in records) {
      batch.insert(table, record, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getAllForSync(String table) async {
    if (kIsWeb) {
      final web = await _web;
      return await web.query(table);
    }
    final db = await database;
    return await db.query(table);
  }

  // ─── Dashboard Queries ───
  // SALES use UTC timestamps; EXPENSES use LOCAL timestamps.
  // Sales queries MUST convert local day boundaries → UTC for correct matching.

  /// Helper: returns UTC ISO strings for [startOfTodayLocal, startOfTomorrowLocal)
  ({String startUtc, String endUtc}) _todayUtcRange() {
    final now = DateTime.now();
    final localStart = DateTime(now.year, now.month, now.day);
    final localEnd = localStart.add(const Duration(days: 1));
    return (
      startUtc: localStart.toUtc().toIso8601String(),
      endUtc: localEnd.toUtc().toIso8601String(),
    );
  }

  Future<double> todaySalesTotal() async {
    final r = _todayUtcRange();
    return await sum('sales', 'total',
        where: "is_deleted = 0 AND created_at >= ? AND created_at < ?",
        whereArgs: [r.startUtc, r.endUtc]);
  }

  Future<int> todaySalesCount() async {
    final r = _todayUtcRange();
    return await count('sales',
        where: "is_deleted = 0 AND created_at >= ? AND created_at < ?",
        whereArgs: [r.startUtc, r.endUtc]);
  }

  Future<double> todayExpensesTotal() async {
    // Expenses store LOCAL timestamps — LIKE query is correct here
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return await sum('expenses', 'amount',
        where: "is_deleted = 0 AND created_at LIKE ?", whereArgs: ['$today%']);
  }

  /// Total RETAIL value of inventory (selling price × quantity)
  /// Used for: Dashboard "Stock Value" card (what inventory could sell for)
  Future<double> totalStockValue() async {
    if (kIsWeb) {
      final web = await _web;
      final items = await web.query('items', where: 'is_deleted = 0');
      double total = 0;
      for (final item in items) {
        total += ((item['price'] as num?) ?? 0) * ((item['quantity'] as num?) ?? 0);
      }
      return total;
    }
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(price * quantity), 0) as total FROM items WHERE is_deleted = 0',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Total COST/INVESTMENT value of inventory (cost_price × quantity)
  /// Used for: Accounting, true investment tracking, potential margin calculation
  Future<double> totalStockCost() async {
    if (kIsWeb) {
      final web = await _web;
      final items = await web.query('items', where: 'is_deleted = 0');
      double total = 0;
      for (final item in items) {
        total += ((item['cost_price'] as num?) ?? 0) * ((item['quantity'] as num?) ?? 0);
      }
      return total;
    }
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(cost_price * quantity), 0) as total FROM items WHERE is_deleted = 0',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> lowStockCount() async {
    if (kIsWeb) {
      final web = await _web;
      final items = await web.query('items', where: 'is_deleted = 0');
      return items.where((i) {
        final qty = (i['quantity'] as num?)?.toInt() ?? 0;
        final threshold = (i['low_stock_threshold'] as num?)?.toInt() ?? 5;
        return qty <= threshold && qty > 0;
      }).length;
    }
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM items WHERE is_deleted = 0 AND quantity <= low_stock_threshold AND quantity > 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> outOfStockCount() async {
    if (kIsWeb) {
      final web = await _web;
      final items = await web.query('items', where: 'is_deleted = 0');
      return items.where((i) => (i['quantity'] as num?)?.toInt() == 0).length;
    }
    return await count('items', where: 'is_deleted = 0 AND quantity = 0');
  }

  Future<List<Map<String, dynamic>>> recentSales({int limit = 10}) async {
    return await query('sales', where: 'is_deleted = 0', orderBy: 'created_at DESC', limit: limit);
  }

  Future<List<Map<String, dynamic>>> lowStockItems() async {
    if (kIsWeb) {
      final web = await _web;
      final items = await web.query('items', where: 'is_deleted = 0', orderBy: 'quantity ASC');
      return items.where((i) {
        final qty = (i['quantity'] as num?)?.toInt() ?? 0;
        final threshold = (i['low_stock_threshold'] as num?)?.toInt() ?? 5;
        return qty <= threshold;
      }).toList();
    }
    final db = await database;
    return await db.rawQuery(
      'SELECT * FROM items WHERE is_deleted = 0 AND quantity <= low_stock_threshold ORDER BY quantity ASC',
    );
  }

  Future<List<Map<String, dynamic>>> salesLast7Days() async {
    // Compute the cutoff: 7 days ago at midnight (local time)
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));

    if (kIsWeb) {
      // Web: in-memory filtering + grouping
      // IMPORTANT: Sales store UTC timestamps. We convert to LOCAL
      // before grouping so chart days match the user's timezone.
      final web = await _web;
      final allSales = await web.query('sales', where: 'is_deleted = 0');
      final Map<String, double> dailyTotals = {};
      final Map<String, int> dailyCounts = {};

      for (final sale in allSales) {
        final createdAt = sale['created_at'] as String?;
        if (createdAt == null) continue;
        final dt = DateTime.tryParse(createdAt);
        if (dt == null) continue;
        // Convert UTC → local for correct day grouping
        final localDt = dt.toLocal();
        if (localDt.isBefore(cutoff)) continue;

        // Group by LOCAL date (not UTC substring)
        final dateKey = '${localDt.year}-${localDt.month.toString().padLeft(2, '0')}-${localDt.day.toString().padLeft(2, '0')}';
        final total = (sale['total'] as num?)?.toDouble() ?? 0;
        dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + total;
        dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
      }

      // Return sorted list matching the native SQL result format
      final result = dailyTotals.entries.map((e) => <String, dynamic>{
        'date': e.key,
        'total': e.value,
        'count': dailyCounts[e.key] ?? 0,
      }).toList()
        ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

      debugPrint('📊 salesLast7Days (web): ${result.length} days, '
          'total ₹${result.fold(0.0, (sum, d) => sum + (d['total'] as double))}');
      return result;
    }

    // Native: use SQL date functions
    // NOTE: SQLite DATE() extracts from the raw string which is UTC.
    // For IST (UTC+5:30), late-night sales may group on wrong day.
    // Using datetime with localtime modifier for correct grouping.
    final db = await database;
    final cutoffStr = cutoff.toUtc().toIso8601String();
    return await db.rawQuery('''
      SELECT DATE(created_at, 'localtime') as date, SUM(total) as total, COUNT(*) as count
      FROM sales
      WHERE is_deleted = 0 AND created_at >= ?
      GROUP BY DATE(created_at, 'localtime')
      ORDER BY date ASC
    ''', [cutoffStr]);
  }

  // ─── Cleanup ───

  Future<void> close() async {
    if (kIsWeb) return;
    final db = await database;
    await db.close();
    _database = null;
  }

  Future<void> clearAllData() async {
    // CRITICAL: sync_queue is NOT cleared — pending offline operations
    // must survive re-login/refresh so they can be pushed to cloud.
    const tables = [
      'items', 'sales', 'expenses', 'cash_till',
      'customers', 'vendors', 'staff', 'attendance', 'purchases',
      'categories', 'clearance_items', 'loyalty_transactions', 'returns', 'revenue_snapshots', 'settings',
    ];
    if (kIsWeb) {
      final web = await _web;
      // Preserve sync_queue before clearing
      final pendingSync = await web.query('sync_queue');
      for (final t in tables) {
        await web.delete(t);
      }
      // Reset _WebDB but re-initialize immediately
      _webDB = null;
      final freshWeb = await _web;
      // Restore sync_queue items
      for (final item in pendingSync) {
        await freshWeb.insert('sync_queue', item);
      }
      debugPrint('🧹 Local DB cleared (${pendingSync.length} sync queue items preserved)');
      return;
    }
    final db = await database;
    for (final t in tables) {
      try {
        await db.delete(t);
      } catch (_) {} // table might not exist yet
    }
    // sync_queue intentionally NOT cleared on native either
  }

  // ─── Revenue Snapshots ───

  /// Save a monthly revenue snapshot to the DB
  Future<void> saveRevenueSnapshot(Map<String, dynamic> snapshot) async {
    final year = snapshot['year'] as int;
    final month = snapshot['month'] as int;
    final id = 'snapshot_${year}_${month.toString().padLeft(2, '0')}';
    final now = DateTime.now().toUtc().toIso8601String();

    // Encode category_revenue map as JSON string
    final catRevenue = snapshot['category_revenue'];
    final catRevenueStr = catRevenue is Map ? jsonEncode(catRevenue) : '{}';

    final record = <String, dynamic>{
      'id': id,
      'year': year,
      'month': month,
      'total_revenue': snapshot['total_revenue'] ?? 0.0,
      'total_profit': snapshot['total_profit'] ?? 0.0,
      'total_discounts': snapshot['total_discounts'] ?? 0.0,
      'total_cogs': snapshot['total_cogs'] ?? 0.0,
      'total_expenses': snapshot['total_expenses'] ?? 0.0,
      'net_profit': snapshot['net_profit'] ?? 0.0,
      'sales_count': snapshot['sales_count'] ?? 0,
      'category_revenue': catRevenueStr,
      'is_deleted': 0,
      'created_at': now,
      'updated_at': now,
    };

    await insert('revenue_snapshots', record);
    debugPrint('📸 Saved revenue snapshot: $year-$month');
  }

  /// Get a specific month's revenue snapshot
  Future<Map<String, dynamic>?> getRevenueSnapshot(int year, int month) async {
    final id = 'snapshot_${year}_${month.toString().padLeft(2, '0')}';
    final result = await getById('revenue_snapshots', id);
    if (result != null && result['category_revenue'] is String) {
      try {
        result['category_revenue'] = jsonDecode(result['category_revenue'] as String);
      } catch (_) {
        result['category_revenue'] = <String, dynamic>{};
      }
    }
    return result;
  }

  /// Get all revenue snapshots (for history view)
  Future<List<Map<String, dynamic>>> getAllRevenueSnapshots() async {
    final results = await getAll('revenue_snapshots', orderBy: 'year DESC, month DESC');
    for (final r in results) {
      if (r['category_revenue'] is String) {
        try {
          r['category_revenue'] = jsonDecode(r['category_revenue'] as String);
        } catch (_) {
          r['category_revenue'] = <String, dynamic>{};
        }
      }
    }
    return results;
  }
}
