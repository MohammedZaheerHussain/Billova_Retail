import 'dart:convert';

class ExpenseModel {
  final String id;
  final double amount;
  final String note;
  final String category;
  final String paymentMode; // 'Cash' or 'UPI' — affects cash till calculation
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExpenseModel({
    required this.id,
    required this.amount,
    this.note = '',
    this.category = 'General',
    this.paymentMode = 'Cash',
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'note': note,
      'category': category,
      'payment_mode': paymentMode,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      note: map['note'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
      paymentMode: map['payment_mode'] as String? ?? 'Cash',
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  ExpenseModel copyWith({
    double? amount,
    String? note,
    String? category,
    String? paymentMode,
    bool? isDeleted,
    DateTime? updatedAt,
  }) {
    return ExpenseModel(
      id: id,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      category: category ?? this.category,
      paymentMode: paymentMode ?? this.paymentMode,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory ExpenseModel.fromJson(String source) => ExpenseModel.fromMap(jsonDecode(source));

  @override
  String toString() => 'ExpenseModel(id: $id, amount: $amount, category: $category, paymentMode: $paymentMode)';
}
