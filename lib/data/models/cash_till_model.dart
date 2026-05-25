import 'dart:convert';

/// Cash Till model — professional retail cash reconciliation.
///
/// Persists: openingCash, actualClosingCash, notes.
/// Computed from sales/expenses: cashSales, upiSales, cardSales,
/// cashExpenses, digitalExpenses.
class CashTillModel {
  final String id;
  final String date; // YYYY-MM-DD
  final double openingCash;
  final double actualClosingCash; // manually counted cash in drawer
  final String notes;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ─── Computed fields (NOT stored in DB — derived from sales/expenses) ───
  final double cashSales;      // Sales paid via Cash ONLY
  final double upiSales;       // Sales paid via UPI
  final double cardSales;      // Sales paid via Card
  final double cashExpenses;   // Expenses paid from shop cash
  final double digitalExpenses; // Expenses paid via UPI/bank

  // Legacy compat
  final double cashIn;         // total sales (all methods combined)
  final double cashOut;        // total expenses (all methods combined)

  CashTillModel({
    required this.id,
    required this.date,
    this.openingCash = 0,
    this.actualClosingCash = -1, // -1 = not yet counted
    this.notes = '',
    this.isDeleted = false,
    this.cashSales = 0,
    this.upiSales = 0,
    this.cardSales = 0,
    this.cashExpenses = 0,
    this.digitalExpenses = 0,
    this.cashIn = 0,
    this.cashOut = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // ─── Computed Getters ───

  /// Expected physical cash in shop drawer
  double get expectedCash => openingCash + cashSales - cashExpenses;

  /// Digital (UPI + Card) collection balance
  double get digitalCollection => upiSales + cardSales - digitalExpenses;

  /// Difference between actual counted cash and expected
  double get cashDifference =>
      actualClosingCash >= 0 ? actualClosingCash - expectedCash : 0;

  /// Whether the owner has entered an actual cash count
  bool get isCashCounted => actualClosingCash >= 0;

  /// Legacy closing balance (opening + all sales - all expenses)
  double get closingBalance => openingCash + cashIn - cashOut;
  double get netFlow => cashIn - cashOut;

  /// Total day's sales (all methods)
  double get totalSales => cashSales + upiSales + cardSales;

  /// Total day's expenses (all methods)
  double get totalExpenses => cashExpenses + digitalExpenses;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'opening_cash': openingCash,
      'actual_closing_cash': actualClosingCash,
      'notes': notes,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CashTillModel.fromMap(
    Map<String, dynamic> map, {
    double cashSales = 0,
    double upiSales = 0,
    double cardSales = 0,
    double cashExpenses = 0,
    double digitalExpenses = 0,
    double cashIn = 0,
    double cashOut = 0,
  }) {
    return CashTillModel(
      id: map['id'] as String,
      date: map['date'] as String,
      openingCash: (map['opening_cash'] as num?)?.toDouble() ?? 0,
      actualClosingCash: (map['actual_closing_cash'] as num?)?.toDouble() ?? -1,
      notes: map['notes'] as String? ?? '',
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      cashSales: cashSales,
      upiSales: upiSales,
      cardSales: cardSales,
      cashExpenses: cashExpenses,
      digitalExpenses: digitalExpenses,
      cashIn: cashIn,
      cashOut: cashOut,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  CashTillModel copyWith({
    double? openingCash,
    double? actualClosingCash,
    String? notes,
    double? cashSales,
    double? upiSales,
    double? cardSales,
    double? cashExpenses,
    double? digitalExpenses,
    double? cashIn,
    double? cashOut,
    bool? isDeleted,
    DateTime? updatedAt,
  }) {
    return CashTillModel(
      id: id,
      date: date,
      openingCash: openingCash ?? this.openingCash,
      actualClosingCash: actualClosingCash ?? this.actualClosingCash,
      notes: notes ?? this.notes,
      cashSales: cashSales ?? this.cashSales,
      upiSales: upiSales ?? this.upiSales,
      cardSales: cardSales ?? this.cardSales,
      cashExpenses: cashExpenses ?? this.cashExpenses,
      digitalExpenses: digitalExpenses ?? this.digitalExpenses,
      cashIn: cashIn ?? this.cashIn,
      cashOut: cashOut ?? this.cashOut,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  @override
  String toString() =>
      'CashTillModel(date: $date, open: $openingCash, cashSales: $cashSales, upi: $upiSales, card: $cardSales, expected: $expectedCash)';
}
