// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import '../../data/local/db_helper.dart';

/// Service for exporting all application data as CSV files.
/// Supports individual table exports or a full data dump.
/// Web-only: uses dart:html AnchorElement for browser downloads.
class DataExportService {
  static final DataExportService instance = DataExportService._();
  DataExportService._();

  final DBHelper _db = DBHelper.instance;

  // ─── Table Definitions ───
  // Each entry: table name → list of column names for CSV header
  static const Map<String, List<String>> _tableColumns = {
    'items': [
      'id', 'name', 'sku', 'barcode', 'category', 'brand', 'size', 'color',
      'mrp', 'selling_price', 'purchase_price', 'quantity', 'min_stock',
      'storage_location', 'vendor_id', 'vendor_name', 'notes',
      'original_price', 'parent_item_id', 'created_at', 'updated_at',
    ],
    'sales': [
      'id', 'invoice_number', 'customer_name', 'customer_phone',
      'items_json', 'subtotal', 'discount', 'total', 'payment_mode',
      'staff_id', 'staff_name', 'loyalty_discount',
      'created_at', 'updated_at',
    ],
    'customers': [
      'id', 'name', 'phone', 'email', 'address', 'notes',
      'total_purchases', 'total_spent', 'loyalty_points',
      'created_at', 'updated_at',
    ],
    'vendors': [
      'id', 'name', 'phone', 'email', 'address', 'gst_number',
      'notes', 'total_purchases', 'total_paid', 'balance',
      'created_at', 'updated_at',
    ],
    'purchases': [
      'id', 'vendor_id', 'vendor_name', 'invoice_number',
      'items_json', 'subtotal', 'discount', 'total',
      'amount_paid', 'payment_mode', 'payment_status', 'notes',
      'created_at', 'updated_at',
    ],
    'expenses': [
      'id', 'category', 'description', 'amount', 'payment_mode',
      'notes', 'created_at', 'updated_at',
    ],
    'staff': [
      'id', 'username', 'name', 'role', 'is_active',
      'monthly_sale_target', 'created_at', 'updated_at',
    ],
    'attendance': [
      'id', 'staff_id', 'staff_name', 'date',
      'clock_in_time', 'clock_out_time', 'total_hours',
      'created_at', 'updated_at',
    ],
    'cash_till': [
      'id', 'date', 'opening_balance', 'cash_in', 'cash_out',
      'closing_balance', 'status', 'notes',
      'created_at', 'updated_at',
    ],
    'categories': [
      'id', 'name', 'requires_size', 'requires_color',
      'created_at', 'updated_at',
    ],
    'clearance_items': [
      'id', 'original_item_id', 'clearance_item_id',
      'quantity', 'original_price', 'clearance_price',
      'reason', 'status', 'created_at', 'updated_at',
    ],
  };

  /// Export a single table as CSV and trigger browser download
  Future<int> exportTable(String tableName) async {
    final columns = _tableColumns[tableName];
    if (columns == null) throw Exception('Unknown table: $tableName');

    final rows = await _db.query(
      tableName,
      where: tableName != 'cash_till' ? 'is_deleted = 0' : null,
    );

    final csv = _buildCsv(columns, rows);
    final timestamp = DateTime.now().toIso8601String().substring(0, 10);
    _triggerDownload(csv, 'SKYWALK_${tableName}_$timestamp.csv');
    return rows.length;
  }

  /// Export ALL tables as a single combined CSV with table separators
  Future<Map<String, int>> exportAll() async {
    final Map<String, int> counts = {};
    final buffer = StringBuffer();
    final timestamp = DateTime.now().toIso8601String().substring(0, 10);

    for (final entry in _tableColumns.entries) {
      final tableName = entry.key;
      final columns = entry.value;

      try {
        final rows = await _db.query(
          tableName,
          where: _hasIsDeleted(tableName) ? 'is_deleted = 0' : null,
        );

        // Section header
        buffer.writeln('');
        buffer.writeln('=== $tableName (${rows.length} records) ===');
        buffer.writeln(_escapeCsvRow(columns));

        for (final row in rows) {
          buffer.writeln(_escapeCsvRow(
            columns.map((col) => _formatValue(row[col])).toList(),
          ));
        }

        counts[tableName] = rows.length;
      } catch (e) {
        debugPrint('Export error for $tableName: $e');
        counts[tableName] = -1; // error marker
      }
    }

    _triggerDownload(buffer.toString(), 'SKYWALK_FULL_BACKUP_$timestamp.csv');
    return counts;
  }

  /// Export monthly report — only records from the given month
  Future<Map<String, int>> exportMonthlyReport({DateTime? month}) async {
    final target = month ?? DateTime.now();
    final monthStart = DateTime(target.year, target.month, 1);
    final monthEnd = DateTime(target.year, target.month + 1, 0, 23, 59, 59);
    final startStr = monthStart.toIso8601String();
    final endStr = monthEnd.toIso8601String();

    final Map<String, int> counts = {};
    final buffer = StringBuffer();
    final monthLabel = '${target.year}-${target.month.toString().padLeft(2, '0')}';

    buffer.writeln('SKYWALK Billing — Monthly Report: $monthLabel');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');

    // Tables with created_at for monthly filtering
    final monthlyTables = ['sales', 'purchases', 'expenses', 'attendance', 'clearance_items'];

    for (final tableName in monthlyTables) {
      final columns = _tableColumns[tableName]!;
      try {
        final rows = await _db.query(
          tableName,
          where: '${_hasIsDeleted(tableName) ? "is_deleted = 0 AND " : ""}created_at >= ? AND created_at <= ?',
          whereArgs: [startStr, endStr],
        );

        buffer.writeln('=== $tableName (${rows.length} records) ===');
        buffer.writeln(_escapeCsvRow(columns));
        for (final row in rows) {
          buffer.writeln(_escapeCsvRow(
            columns.map((col) => _formatValue(row[col])).toList(),
          ));
        }
        buffer.writeln('');
        counts[tableName] = rows.length;
      } catch (e) {
        debugPrint('Monthly export error for $tableName: $e');
        counts[tableName] = -1;
      }
    }

    // Always include full inventory snapshot
    final itemCols = _tableColumns['items']!;
    try {
      final items = await _db.query('items', where: 'is_deleted = 0');
      buffer.writeln('=== items — Full Inventory Snapshot (${items.length} records) ===');
      buffer.writeln(_escapeCsvRow(itemCols));
      for (final row in items) {
        buffer.writeln(_escapeCsvRow(
          itemCols.map((col) => _formatValue(row[col])).toList(),
        ));
      }
      counts['items'] = items.length;
    } catch (e) {
      counts['items'] = -1;
    }

    // Customer snapshot
    final custCols = _tableColumns['customers']!;
    try {
      final customers = await _db.query('customers', where: 'is_deleted = 0');
      buffer.writeln('');
      buffer.writeln('=== customers — Snapshot (${customers.length} records) ===');
      buffer.writeln(_escapeCsvRow(custCols));
      for (final row in customers) {
        buffer.writeln(_escapeCsvRow(
          custCols.map((col) => _formatValue(row[col])).toList(),
        ));
      }
      counts['customers'] = customers.length;
    } catch (e) {
      counts['customers'] = -1;
    }

    _triggerDownload(buffer.toString(), 'SKYWALK_MONTHLY_${monthLabel}.csv');
    return counts;
  }

  // ─── Helpers ───

  bool _hasIsDeleted(String table) {
    return !['cash_till', 'clearance_items', 'categories'].contains(table);
  }

  String _formatValue(dynamic value) {
    if (value == null) return '';
    if (value is int && (value == 0 || value == 1)) {
      // Keep as int, don't convert to bool
      return value.toString();
    }
    return value.toString();
  }

  String _escapeCsvRow(List<String> values) {
    return values.map((v) {
      // Escape quotes and wrap in quotes if contains comma, newline, or quote
      if (v.contains(',') || v.contains('\n') || v.contains('"')) {
        return '"${v.replaceAll('"', '""')}"';
      }
      return v;
    }).join(',');
  }

  String _buildCsv(List<String> columns, List<Map<String, dynamic>> rows) {
    final buffer = StringBuffer();
    buffer.writeln(_escapeCsvRow(columns));
    for (final row in rows) {
      buffer.writeln(_escapeCsvRow(
        columns.map((col) => _formatValue(row[col])).toList(),
      ));
    }
    return buffer.toString();
  }

  void _triggerDownload(String content, String filename) {
    if (!kIsWeb) return;
    final bytes = utf8.encode(content);
    // Add BOM for Excel to recognize UTF-8
    final bom = [0xEF, 0xBB, 0xBF];
    final blob = html.Blob([bom, bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
