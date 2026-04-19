import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/local/db_helper.dart';
import '../data/remote/supabase_service.dart';
import '../data/models/cash_till_model.dart';

class CashTillProvider extends ChangeNotifier {
  final DBHelper _db = DBHelper.instance;
  final SupabaseService _supabase = SupabaseService.instance;
  final _uuid = const Uuid();

  CashTillModel? _today;
  bool _isLoading = false;
  String _error = '';

  CashTillModel? get today => _today;
  bool get isLoading => _isLoading;
  String get error => _error;

  String get _todayDate => DateTime.now().toIso8601String().substring(0, 10);

  /// Load today's cash till with computed cashIn/cashOut
  Future<void> loadToday() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      // Get or create today's record
      final maps = await _db.query(
        'cash_till',
        where: "date = ? AND is_deleted = 0",
        whereArgs: [_todayDate],
      );

      // Compute cash in (today's sales) and cash out (today's expenses)
      final cashIn = await _db.todaySalesTotal();
      final cashOut = await _db.todayExpensesTotal();

      if (maps.isNotEmpty) {
        _today = CashTillModel.fromMap(maps.first, cashIn: cashIn, cashOut: cashOut);
      } else {
        // Auto-create today's record
        final till = CashTillModel(
          id: _uuid.v4(),
          date: _todayDate,
          openingCash: 0,
          cashIn: cashIn,
          cashOut: cashOut,
        );
        await _db.insert('cash_till', till.toMap());
        await _supabase.syncRecord('cash_till', till.id, 'insert', till.toMap());
        _today = till;
      }
    } catch (e) {
      _error = 'Failed to load cash till: $e';
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
      final cashIn = await _db.todaySalesTotal();
      final cashOut = await _db.todayExpensesTotal();
      _today = _today!.copyWith(cashIn: cashIn, cashOut: cashOut);
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

  void clearError() {
    _error = '';
    notifyListeners();
  }
}
