import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/local/db_helper.dart';
import '../data/remote/supabase_service.dart';
import '../data/models/expense_model.dart';
import '../core/utils/date_filter.dart';

class ExpenseProvider extends ChangeNotifier {
  final DBHelper _db = DBHelper.instance;
  final SupabaseService _supabase = SupabaseService.instance;
  final _uuid = const Uuid();

  // All expenses (loaded once)
  List<ExpenseModel> _allExpenses = [];
  // Filtered expenses (based on date filter)
  List<ExpenseModel> _filteredExpenses = [];
  bool _isLoading = false;
  String _error = '';

  // Date filter state
  DateFilterType _filterType = DateFilterType.today;
  DateTime? _customStart;
  DateTime? _customEnd;

  // Getters
  List<ExpenseModel> get expenses => _filteredExpenses;
  bool get isLoading => _isLoading;
  String get error => _error;
  DateFilterType get filterType => _filterType;
  DateTime? get customStart => _customStart;
  DateTime? get customEnd => _customEnd;
  double get totalExpenses => _filteredExpenses.fold(0, (sum, e) => sum + e.amount);
  int get expenseCount => _filteredExpenses.length;

  /// Grouped expenses by date (for UI rendering)
  Map<String, List<ExpenseModel>> get groupedExpenses {
    final Map<String, List<ExpenseModel>> groups = {};
    for (final expense in _filteredExpenses) {
      final dateKey = DateFilterHelper.groupLabel(expense.createdAt);
      groups.putIfAbsent(dateKey, () => []);
      groups[dateKey]!.add(expense);
    }
    return groups;
  }

  /// Load all expenses from DB (called once on app start)
  Future<void> loadExpenses() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final maps = await _db.getAll('expenses', orderBy: 'created_at DESC');
      _allExpenses = maps.map((m) => ExpenseModel.fromMap(m)).toList();
      _applyFilter();
      debugPrint('📋 ExpenseProvider: loaded ${_allExpenses.length} expenses');
    } catch (e) {
      _error = 'Failed to load expenses: $e';
      debugPrint('❌ $_error');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Change date filter
  void setFilter(DateFilterType type, {DateTime? customStart, DateTime? customEnd}) {
    _filterType = type;
    if (type == DateFilterType.custom) {
      _customStart = customStart;
      _customEnd = customEnd;
    }
    _applyFilter();
    notifyListeners();
  }

  /// Apply the current filter to the full expense list
  void _applyFilter() {
    final range = DateFilterHelper.getRange(
      _filterType,
      customStart: _customStart,
      customEnd: _customEnd,
    );

    _filteredExpenses = _allExpenses.where((e) {
      // createdAt is already local (stripped in fromMap) — no toLocal() needed
      return !e.createdAt.isBefore(range.start) && e.createdAt.isBefore(range.end);
    }).toList();
  }

  /// Add a new expense
  Future<bool> addExpense({
    required double amount,
    String note = '',
    String category = 'General',
    String paymentMode = 'Cash',
  }) async {
    try {
      final expense = ExpenseModel(
        id: _uuid.v4(),
        amount: amount,
        note: note,
        category: category,
        paymentMode: paymentMode,
      );

      debugPrint('➕ ExpenseProvider: adding expense ₹$amount ($category)');

      // Save to local DB
      await _db.insert('expenses', expense.toMap());

      // Add to full list + re-filter
      _allExpenses.insert(0, expense);
      _applyFilter();
      notifyListeners();

      // Sync to Supabase
      if (kIsWeb) {
        await _supabase.syncRecord('expenses', expense.id, 'insert', expense.toMap());
      } else {
        _supabase.syncRecord('expenses', expense.id, 'insert', expense.toMap());
      }

      return true;
    } catch (e) {
      _error = 'Failed to add expense: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete an expense
  Future<bool> deleteExpense(String id) async {
    try {
      await _db.softDelete('expenses', id);
      final expense = _allExpenses.firstWhere((e) => e.id == id);

      _allExpenses.removeWhere((e) => e.id == id);
      _applyFilter();
      notifyListeners();

      if (kIsWeb) {
        await _supabase.syncRecord('expenses', id, 'delete', expense.toMap());
      } else {
        _supabase.syncRecord('expenses', id, 'delete', expense.toMap());
      }
      return true;
    } catch (e) {
      _error = 'Failed to delete expense: $e';
      notifyListeners();
      return false;
    }
  }

  /// Get total expenses for a specific date string (used by dashboard/cash_till)
  Future<double> expensesForDate(String dateStr) async {
    return await _db.sum(
      'expenses',
      'amount',
      where: "is_deleted = 0 AND created_at LIKE ?",
      whereArgs: ['$dateStr%'],
    );
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }
}
