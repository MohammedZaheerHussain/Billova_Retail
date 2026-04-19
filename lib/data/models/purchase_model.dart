import 'dart:convert';

class PurchaseModel {
  final String id;
  final String vendorId;
  final String vendorName;
  final String items; // JSON string
  final double totalAmount;
  final double paidAmount;
  final String paymentMode;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  PurchaseModel({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.items,
    required this.totalAmount,
    this.paidAmount = 0,
    this.paymentMode = 'Cash',
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get dueAmount => totalAmount - paidAmount;
  bool get isFullyPaid => dueAmount <= 0;

  List<Map<String, dynamic>> get itemsList {
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(items));
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'vendor_name': vendorName,
      'items': items,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'payment_mode': paymentMode,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PurchaseModel.fromMap(Map<String, dynamic> map) {
    return PurchaseModel(
      id: map['id'] as String,
      vendorId: map['vendor_id'] as String,
      vendorName: (map['vendor_name'] as String?) ?? '',
      items: map['items'] is String ? map['items'] as String : jsonEncode(map['items']),
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0,
      paymentMode: (map['payment_mode'] as String?) ?? 'Cash',
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());

  @override
  String toString() =>
      'PurchaseModel(id: $id, vendor: $vendorName, total: $totalAmount, paid: $paidAmount, due: $dueAmount)';
}
