import 'dart:convert';

/// Cash Till model.
/// Only stores `opening_cash` — `cashIn` and `cashOut` are computed
/// from sales and expenses tables respectively.
class CashTillModel {
  final String id;
  final String date; // YYYY-MM-DD
  final double openingCash;
  final String notes;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed fields (not stored in DB)
  final double cashIn;
  final double cashOut;

  CashTillModel({
    required this.id,
    required this.date,
    this.openingCash = 0,
    this.notes = '',
    this.isDeleted = false,
    this.cashIn = 0,
    this.cashOut = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get closingBalance => openingCash + cashIn - cashOut;
  double get netFlow => cashIn - cashOut;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'opening_cash': openingCash,
      'notes': notes,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CashTillModel.fromMap(Map<String, dynamic> map, {double cashIn = 0, double cashOut = 0}) {
    return CashTillModel(
      id: map['id'] as String,
      date: map['date'] as String,
      openingCash: (map['opening_cash'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String? ?? '',
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      cashIn: cashIn,
      cashOut: cashOut,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  CashTillModel copyWith({
    double? openingCash,
    String? notes,
    double? cashIn,
    double? cashOut,
    bool? isDeleted,
    DateTime? updatedAt,
  }) {
    return CashTillModel(
      id: id,
      date: date,
      openingCash: openingCash ?? this.openingCash,
      notes: notes ?? this.notes,
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
      'CashTillModel(date: $date, open: $openingCash, in: $cashIn, out: $cashOut, balance: $closingBalance)';
}
