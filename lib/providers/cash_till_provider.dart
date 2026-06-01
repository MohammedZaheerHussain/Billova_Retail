import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/local/db_helper.dart';
import '../data/remote/supabase_service.dart';
import '../data/models/cash_till_model.dart';
import '../data/models/sale_model.dart';
import '../data/models/expense_model.dart';

/// Professional retail cash reconciliation provider.
///
/// Separates Cash / UPI / Card channels for both sales and expenses.
/// Physical shop cash = Opening + Cash Sales − Cash Expenses.
/// UPI/Card money goes to bank — NOT part of physical cash drawer.
class CashTillProvider extends ChangeNotifier {
  final DBHelper _db = DBHelper.instance;
  final SupabaseService _supabase = SupabaseService.instance;
  final _uuid = const Uuid();

  CashTillModel? _today;
  List<CashTillModel> _history = [];
  bool _isLoading = false;
  String _error = '';

  CashTillModel? get today => _today;
  List<CashTillModel> get history => _history;
  bool get isLoading => _isLoading;
  String get error => _error;

  String get _todayDate => DateTime.now().toIso8601String().substring(0, 10);

  /// Load today's cash till with payment-method-separated totals
  Future<void> loadToday() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      // Get or create today's DB record
      final maps = await _db.query(
        'cash_till',
        where: "date = ? AND is_deleted = 0",
        whereArgs: [_todayDate],
      );

      // ═══════════════════════════════════════════════════════════
      // Compute sales breakdown by payment method from sales table
      // ═══════════════════════════════════════════════════════════
      final salesBreakdown = await _computeTodaySalesBreakdown();
      final expenseBreakdown = await _computeTodayExpenseBreakdown();
      final cashRefunds = await _computeTodayCashRefunds();

      if (maps.isNotEmpty) {
        _today = CashTillModel.fromMap(
          maps.first,
          cashSales: salesBreakdown['cash']!,
          upiSales: salesBreakdown['upi']!,
          cardSales: salesBreakdown['card']!,
          cashExpenses: expenseBreakdown['cash']!,
          digitalExpenses: expenseBreakdown['digital']!,
          cashIn: salesBreakdown['total']!,
          cashOut: expenseBreakdown['total']!,
          cashRefunds: cashRefunds,
        );
      } else {
        // Auto-create today's record
        final till = CashTillModel(
          id: _uuid.v4(),
          date: _todayDate,
          openingCash: 0,
          cashSales: salesBreakdown['cash']!,
          upiSales: salesBreakdown['upi']!,
          cardSales: salesBreakdown['card']!,
          cashExpenses: expenseBreakdown['cash']!,
          digitalExpenses: expenseBreakdown['digital']!,
          cashIn: salesBreakdown['total']!,
          cashOut: expenseBreakdown['total']!,
          cashRefunds: cashRefunds,
        );
        await _db.insert('cash_till', till.toMap());
        await _supabase.syncRecord('cash_till', till.id, 'insert', till.toMap());
        _today = till;
      }
    } catch (e) {
      _error = 'Failed to load cash till: $e';
      debugPrint('❌ $_error');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Refresh computed values (call after new sale or expense)
  Future<void> refresh() async {
    if (_today == null) {
      await loadToday();
      return;
    }

    try {
      final salesBreakdown = await _computeTodaySalesBreakdown();
      final expenseBreakdown = await _computeTodayExpenseBreakdown();
      final cashRefunds = await _computeTodayCashRefunds();

      _today = _today!.copyWith(
        cashSales: salesBreakdown['cash'],
        upiSales: salesBreakdown['upi'],
        cardSales: salesBreakdown['card'],
        cashExpenses: expenseBreakdown['cash'],
        digitalExpenses: expenseBreakdown['digital'],
        cashIn: salesBreakdown['total'],
        cashOut: expenseBreakdown['total'],
        cashRefunds: cashRefunds,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Cash till refresh failed: $e');
    }
  }

  /// Set opening cash for today
  Future<bool> setOpeningCash(double amount) async {
    if (_today == null) await loadToday();

    try {
      final updated = _today!.copyWith(openingCash: amount);
      await _db.update('cash_till', updated.toMap(), updated.id);
      await _supabase.syncRecord('cash_till', updated.id, 'update', updated.toMap());
      _today = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update opening cash: $e';
      notifyListeners();
      return false;
    }
  }

  /// Set actual closing cash (manually counted by shop owner)
  Future<bool> setActualClosingCash(double amount) async {
    if (_today == null) await loadToday();

    try {
      final updated = _today!.copyWith(actualClosingCash: amount);
      await _db.update('cash_till', updated.toMap(), updated.id);
      await _supabase.syncRecord('cash_till', updated.id, 'update', updated.toMap());
      _today = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update closing cash: $e';
      notifyListeners();
      return false;
    }
  }

  /// Load history for past till records — enriched with computed payment breakdowns
  Future<void> loadHistory() async {
    try {
      final maps = await _db.query(
        'cash_till',
        where: "is_deleted = 0",
        orderBy: 'date DESC',
        limit: 30,
      );

      // Enrich each record with computed sales/expense/refund breakdowns
      final enriched = <CashTillModel>[];
      for (final m in maps) {
        final base = CashTillModel.fromMap(m);
        final dateStr = base.date; // 'YYYY-MM-DD' local

        final sales = await _computeSalesBreakdownForDate(dateStr);
        final expenses = await _computeExpenseBreakdownForDate(dateStr);
        final refunds = await _computeCashRefundsForDate(dateStr);

        enriched.add(base.copyWith(
          cashSales: sales['cash'] ?? 0,
          upiSales: sales['upi'] ?? 0,
          cardSales: sales['card'] ?? 0,
          cashExpenses: expenses['cash'] ?? 0,
          cashRefunds: refunds,
        ));
      }

      _history = enriched;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load cash till history: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // PRIVATE: Compute today's sales broken down by payment method
  // IMPORTANT: Sales store created_at in UTC. We must convert
  // local day boundaries → UTC for correct filtering.
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, double>> _computeTodaySalesBreakdown() async {
    final now = DateTime.now();
    final localStart = DateTime(now.year, now.month, now.day);
    final localEnd = localStart.add(const Duration(days: 1));
    final startUtc = localStart.toUtc().toIso8601String();
    final endUtc = localEnd.toUtc().toIso8601String();

    final salesMaps = await _db.query(
      'sales',
      where: "is_deleted = 0 AND created_at >= ? AND created_at < ?",
      whereArgs: [startUtc, endUtc],
    );

    double cashTotal = 0;
    double upiTotal = 0;
    double cardTotal = 0;

    for (final map in salesMaps) {
      final sale = SaleModel.fromMap(map);
      // Use actual split amounts (cashAmount, upiAmount, cardAmount)
      // These are populated during billing and handle split payments
      cashTotal += sale.cashAmount;
      upiTotal += sale.upiAmount;
      cardTotal += sale.cardAmount;
    }

    return {
      'cash': double.parse(cashTotal.toStringAsFixed(2)),
      'upi': double.parse(upiTotal.toStringAsFixed(2)),
      'card': double.parse(cardTotal.toStringAsFixed(2)),
      'total': double.parse((cashTotal + upiTotal + cardTotal).toStringAsFixed(2)),
    };
  }

  // ═══════════════════════════════════════════════════════════
  // PRIVATE: Compute today's expenses broken down by payment method
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, double>> _computeTodayExpenseBreakdown() async {
    final today = _todayDate;
    final expenseMaps = await _db.query(
      'expenses',
      where: "is_deleted = 0 AND created_at LIKE ?",
      whereArgs: ['$today%'],
    );

    double cashTotal = 0;
    double digitalTotal = 0;

    for (final map in expenseMaps) {
      final expense = ExpenseModel.fromMap(map);
      final mode = expense.paymentMode.toLowerCase();
      if (mode == 'cash' || mode.isEmpty) {
        cashTotal += expense.amount;
      } else {
        digitalTotal += expense.amount;
      }
    }

    return {
      'cash': double.parse(cashTotal.toStringAsFixed(2)),
      'digital': double.parse(digitalTotal.toStringAsFixed(2)),
      'total': double.parse((cashTotal + digitalTotal).toStringAsFixed(2)),
    };
  }

  // ═══════════════════════════════════════════════════════════
  // PRIVATE: Compute today's cash refunds from returns table
  // Returns are stored with UTC timestamps (same as sales).
  // ═══════════════════════════════════════════════════════════
  Future<double> _computeTodayCashRefunds() async {
    final now = DateTime.now();
    final localStart = DateTime(now.year, now.month, now.day);
    final localEnd = localStart.add(const Duration(days: 1));
    final startUtc = localStart.toUtc().toIso8601String();
    final endUtc = localEnd.toUtc().toIso8601String();

    try {
      final returnMaps = await _db.query(
        'returns',
        where: "is_deleted = 0 AND created_at >= ? AND created_at < ?",
        whereArgs: [startUtc, endUtc],
      );

      double cashRefunds = 0;
      for (final map in returnMaps) {
        final method = (map['refund_method'] as String? ?? '').toLowerCase();
        if (method != 'cash') continue;

        final type = map['type'] as String? ?? 'return';
        if (type == 'return') {
          cashRefunds += (map['refund_amount'] as num?)?.toDouble() ?? 0;
        } else if (type == 'exchange') {
          // Negative net_settlement means customer gets money back
          final net = (map['net_settlement'] as num?)?.toDouble() ?? 0;
          if (net < 0) cashRefunds += net.abs();
        }
      }

      return double.parse(cashRefunds.toStringAsFixed(2));
    } catch (e) {
      // Table might not exist yet on first run before migration
      debugPrint('⚠️ Cash refunds query failed (returns table may not exist yet): $e');
      return 0;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // PRIVATE: Compute sales breakdown for a specific date string (YYYY-MM-DD)
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, double>> _computeSalesBreakdownForDate(String dateStr) async {
    final localStart = DateTime.parse(dateStr);
    final localEnd = localStart.add(const Duration(days: 1));
    final startUtc = localStart.toUtc().toIso8601String();
    final endUtc = localEnd.toUtc().toIso8601String();

    final salesMaps = await _db.query(
      'sales',
      where: "is_deleted = 0 AND created_at >= ? AND created_at < ?",
      whereArgs: [startUtc, endUtc],
    );

    double cashTotal = 0, upiTotal = 0, cardTotal = 0;
    for (final map in salesMaps) {
      final sale = SaleModel.fromMap(map);
      cashTotal += sale.cashAmount;
      upiTotal += sale.upiAmount;
      cardTotal += sale.cardAmount;
    }

    return {
      'cash': double.parse(cashTotal.toStringAsFixed(2)),
      'upi': double.parse(upiTotal.toStringAsFixed(2)),
      'card': double.parse(cardTotal.toStringAsFixed(2)),
      'total': double.parse((cashTotal + upiTotal + cardTotal).toStringAsFixed(2)),
    };
  }

  // ═══════════════════════════════════════════════════════════
  // PRIVATE: Compute expense breakdown for a specific date string
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, double>> _computeExpenseBreakdownForDate(String dateStr) async {
    final expenseMaps = await _db.query(
      'expenses',
      where: "is_deleted = 0 AND created_at LIKE ?",
      whereArgs: ['$dateStr%'],
    );

    double cashTotal = 0, digitalTotal = 0;
    for (final map in expenseMaps) {
      final expense = ExpenseModel.fromMap(map);
      final mode = expense.paymentMode.toLowerCase();
      if (mode == 'cash' || mode.isEmpty) {
        cashTotal += expense.amount;
      } else {
        digitalTotal += expense.amount;
      }
    }

    return {
      'cash': double.parse(cashTotal.toStringAsFixed(2)),
      'digital': double.parse(digitalTotal.toStringAsFixed(2)),
      'total': double.parse((cashTotal + digitalTotal).toStringAsFixed(2)),
    };
  }

  // ═══════════════════════════════════════════════════════════
  // PRIVATE: Compute cash refunds for a specific date string
  // ═══════════════════════════════════════════════════════════
  Future<double> _computeCashRefundsForDate(String dateStr) async {
    final localStart = DateTime.parse(dateStr);
    final localEnd = localStart.add(const Duration(days: 1));
    final startUtc = localStart.toUtc().toIso8601String();
    final endUtc = localEnd.toUtc().toIso8601String();

    try {
      final returnMaps = await _db.query(
        'returns',
        where: "is_deleted = 0 AND created_at >= ? AND created_at < ?",
        whereArgs: [startUtc, endUtc],
      );

      double cashRefunds = 0;
      for (final map in returnMaps) {
        final method = (map['refund_method'] as String? ?? '').toLowerCase();
        if (method != 'cash') continue;
        final type = map['type'] as String? ?? 'return';
        if (type == 'return') {
          cashRefunds += (map['refund_amount'] as num?)?.toDouble() ?? 0;
        } else if (type == 'exchange') {
          final net = (map['net_settlement'] as num?)?.toDouble() ?? 0;
          if (net < 0) cashRefunds += net.abs();
        }
      }
      return double.parse(cashRefunds.toStringAsFixed(2));
    } catch (e) {
      return 0;
    }
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }
}
