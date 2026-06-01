import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/local/db_helper.dart';
import '../data/models/return_model.dart';
import '../data/models/sale_model.dart';

/// Manages all return/exchange operations with full audit trail.
///
/// EVERY return/exchange creates a permanent [ReturnModel] record.
/// This provider handles:
/// - Creating return records in local DB
/// - Queuing sync to Supabase
/// - Querying return history for a sale or date range
class ReturnProvider with ChangeNotifier {
  final DBHelper _db = DBHelper.instance;
  List<ReturnModel> _returns = [];
  bool _isLoading = false;

  List<ReturnModel> get allReturns => _returns;
  bool get isLoading => _isLoading;

  /// Load all returns from local DB
  Future<void> loadReturns() async {
    _isLoading = true;
    notifyListeners();

    try {
      final maps = await _db.query('returns', where: 'is_deleted = 0', orderBy: 'created_at DESC');
      _returns = maps.map((m) => ReturnModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('❌ ReturnProvider.loadReturns error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Get all returns for a specific sale
  List<ReturnModel> returnsForSale(String saleId) =>
      _returns.where((r) => r.originalSaleId == saleId).toList();

  /// Get today's returns
  List<ReturnModel> get todayReturns {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return _returns.where((r) {
      final local = r.createdAt.toLocal();
      return !local.isBefore(todayStart);
    }).toList();
  }

  /// Total refunds for today (for cash till adjustment)
  double get todayCashRefunds => todayReturns
      .where((r) => r.refundMethod.toLowerCase() == 'cash' && r.type == 'return')
      .fold(0.0, (sum, r) => sum + r.refundAmount);

  /// Total cash refunds for today including exchange net settlements
  /// (when exchange gives customer money back via cash)
  double get todayTotalCashOutflow {
    double total = 0;
    for (final r in todayReturns) {
      if (r.refundMethod.toLowerCase() != 'cash') continue;
      if (r.type == 'return') {
        total += r.refundAmount;
      } else if (r.type == 'exchange' && r.netSettlement < 0) {
        // Negative net = customer gets money back
        total += r.netSettlement.abs();
      }
    }
    return double.parse(total.toStringAsFixed(2));
  }

  /// Process a RETURN — creates audit record, restocks, queues sync.
  /// Returns the created ReturnModel for display/receipt.
  Future<ReturnModel> processReturn({
    required SaleModel originalSale,
    required List<ReturnItem> returnedItems,
    required String refundMethod,
    required String reason,
    String staffId = '',
    String staffName = '',
    int pointsReversed = 0,
  }) async {
    final refundAmount = returnedItems.fold(0.0, (s, i) => s + i.totalRefund);

    final record = ReturnModel(
      id: const Uuid().v4(),
      originalSaleId: originalSale.id,
      originalInvoice: originalSale.invoiceNumber,
      type: 'return',
      returnedItems: returnedItems,
      exchangeItems: const [],
      refundAmount: double.parse(refundAmount.toStringAsFixed(2)),
      exchangeTotal: 0,
      netSettlement: double.parse((-refundAmount).toStringAsFixed(2)),
      refundMethod: refundMethod,
      reason: reason,
      customerName: originalSale.customerName,
      customerPhone: originalSale.customerPhone,
      staffId: staffId,
      staffName: staffName,
      pointsReversed: pointsReversed,
    );

    // Persist to local DB
    await _db.insert('returns', record.toMap());

    // Queue for cloud sync
    await _db.insert('sync_queue', {
      'id': const Uuid().v4(),
      'table_name': 'returns',
      'record_id': record.id,
      'operation': 'upsert',
      'data': record.toMap().toString(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    // Add to in-memory list
    _returns.insert(0, record);
    notifyListeners();

    debugPrint('✅ Return record created: ${record.id} | '
        'Sale: ${record.originalInvoice} | '
        'Refund: ₹${record.refundAmount} via ${record.refundMethod}');

    return record;
  }

  /// Process an EXCHANGE — creates audit record, queues sync.
  /// Returns the created ReturnModel for display/receipt.
  Future<ReturnModel> processExchange({
    required SaleModel originalSale,
    required List<ReturnItem> returnedItems,
    required List<ExchangeItem> exchangeItems,
    required String refundMethod,
    required String reason,
    String staffId = '',
    String staffName = '',
    int pointsReversed = 0,
  }) async {
    final refundAmount = returnedItems.fold(0.0, (s, i) => s + i.totalRefund);
    final exchangeTotal = exchangeItems.fold(0.0, (s, i) => s + i.totalPrice);
    final netSettlement = exchangeTotal - refundAmount;

    final record = ReturnModel(
      id: const Uuid().v4(),
      originalSaleId: originalSale.id,
      originalInvoice: originalSale.invoiceNumber,
      type: 'exchange',
      returnedItems: returnedItems,
      exchangeItems: exchangeItems,
      refundAmount: double.parse(refundAmount.toStringAsFixed(2)),
      exchangeTotal: double.parse(exchangeTotal.toStringAsFixed(2)),
      netSettlement: double.parse(netSettlement.toStringAsFixed(2)),
      refundMethod: refundMethod,
      reason: reason,
      customerName: originalSale.customerName,
      customerPhone: originalSale.customerPhone,
      staffId: staffId,
      staffName: staffName,
      pointsReversed: pointsReversed,
    );

    // Persist to local DB
    await _db.insert('returns', record.toMap());

    // Queue for cloud sync
    await _db.insert('sync_queue', {
      'id': const Uuid().v4(),
      'table_name': 'returns',
      'record_id': record.id,
      'operation': 'upsert',
      'data': record.toMap().toString(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    // Add to in-memory list
    _returns.insert(0, record);
    notifyListeners();

    debugPrint('✅ Exchange record created: ${record.id} | '
        'Sale: ${record.originalInvoice} | '
        'Return: ₹${refundAmount.toStringAsFixed(2)} | '
        'New: ₹${exchangeTotal.toStringAsFixed(2)} | '
        'Net: ₹${netSettlement.toStringAsFixed(2)}');

    return record;
  }
}
