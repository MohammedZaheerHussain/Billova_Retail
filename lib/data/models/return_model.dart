import 'dart:convert';

/// Represents a single returned item within a return transaction.
class ReturnItem {
  final String itemId;
  final String name;
  final int quantity;
  final double refundPerUnit; // effective paid price per unit (discount-adjusted)
  final double costPrice;     // original cost price for profit reversal

  const ReturnItem({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.refundPerUnit,
    this.costPrice = 0,
  });

  double get totalRefund => refundPerUnit * quantity;
  double get totalCost => costPrice * quantity;

  Map<String, dynamic> toMap() => {
    'item_id': itemId,
    'name': name,
    'quantity': quantity,
    'refund_per_unit': refundPerUnit,
    'cost_price': costPrice,
  };

  factory ReturnItem.fromMap(Map<String, dynamic> map) => ReturnItem(
    itemId: map['item_id'] as String? ?? '',
    name: map['name'] as String? ?? '',
    quantity: (map['quantity'] as num?)?.toInt() ?? 0,
    refundPerUnit: (map['refund_per_unit'] as num?)?.toDouble() ?? 0,
    costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0,
  );
}

/// Represents a new item given in an exchange.
class ExchangeItem {
  final String itemId;
  final String name;
  final int quantity;
  final double price; // selling price per unit

  const ExchangeItem({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.price,
  });

  double get totalPrice => price * quantity;

  Map<String, dynamic> toMap() => {
    'item_id': itemId,
    'name': name,
    'quantity': quantity,
    'price': price,
  };

  factory ExchangeItem.fromMap(Map<String, dynamic> map) => ExchangeItem(
    itemId: map['item_id'] as String? ?? '',
    name: map['name'] as String? ?? '',
    quantity: (map['quantity'] as num?)?.toInt() ?? 0,
    price: (map['price'] as num?)?.toDouble() ?? 0,
  );
}

/// Full return/exchange transaction model.
/// Every return/exchange creates exactly one ReturnModel record.
class ReturnModel {
  final String id;
  final String originalSaleId;
  final String originalInvoice;
  final String type; // 'return' or 'exchange'

  // Items
  final List<ReturnItem> returnedItems;
  final List<ExchangeItem> exchangeItems;

  // Financial
  final double refundAmount;     // total refund to customer
  final double exchangeTotal;    // total value of new exchange items
  final double netSettlement;    // exchangeTotal - refundAmount

  final String refundMethod;     // Cash / UPI / Store Credit

  // Context
  final String reason;
  final String customerName;
  final String customerPhone;
  final String staffId;
  final String staffName;

  // Loyalty
  final int pointsReversed;

  // Metadata
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReturnModel({
    required this.id,
    required this.originalSaleId,
    this.originalInvoice = '',
    this.type = 'return',
    this.returnedItems = const [],
    this.exchangeItems = const [],
    this.refundAmount = 0,
    this.exchangeTotal = 0,
    this.netSettlement = 0,
    this.refundMethod = 'Cash',
    this.reason = '',
    this.customerName = '',
    this.customerPhone = '',
    this.staffId = '',
    this.staffName = '',
    this.pointsReversed = 0,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  /// Total items returned
  int get totalReturnedQty => returnedItems.fold(0, (s, i) => s + i.quantity);

  /// Total cost of returned items (for profit reversal)
  double get totalReturnedCost => returnedItems.fold(0.0, (s, i) => s + i.totalCost);

  Map<String, dynamic> toMap() => {
    'id': id,
    'original_sale_id': originalSaleId,
    'original_invoice': originalInvoice,
    'type': type,
    'returned_items': jsonEncode(returnedItems.map((e) => e.toMap()).toList()),
    'exchange_items': jsonEncode(exchangeItems.map((e) => e.toMap()).toList()),
    'refund_amount': refundAmount,
    'exchange_total': exchangeTotal,
    'net_settlement': netSettlement,
    'refund_method': refundMethod,
    'reason': reason,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'staff_id': staffId,
    'staff_name': staffName,
    'points_reversed': pointsReversed,
    'is_deleted': isDeleted ? 1 : 0,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory ReturnModel.fromMap(Map<String, dynamic> map) {
    // Parse returned items
    List<ReturnItem> returnedItems = [];
    final retData = map['returned_items'];
    if (retData is String && retData.isNotEmpty) {
      final decoded = jsonDecode(retData) as List;
      returnedItems = decoded.map((e) => ReturnItem.fromMap(e as Map<String, dynamic>)).toList();
    } else if (retData is List) {
      returnedItems = retData.map((e) => ReturnItem.fromMap(e as Map<String, dynamic>)).toList();
    }

    // Parse exchange items
    List<ExchangeItem> exchangeItems = [];
    final exchData = map['exchange_items'];
    if (exchData is String && exchData.isNotEmpty) {
      final decoded = jsonDecode(exchData) as List;
      exchangeItems = decoded.map((e) => ExchangeItem.fromMap(e as Map<String, dynamic>)).toList();
    } else if (exchData is List) {
      exchangeItems = exchData.map((e) => ExchangeItem.fromMap(e as Map<String, dynamic>)).toList();
    }

    return ReturnModel(
      id: map['id'] as String,
      originalSaleId: map['original_sale_id'] as String? ?? '',
      originalInvoice: map['original_invoice'] as String? ?? '',
      type: map['type'] as String? ?? 'return',
      returnedItems: returnedItems,
      exchangeItems: exchangeItems,
      refundAmount: (map['refund_amount'] as num?)?.toDouble() ?? 0,
      exchangeTotal: (map['exchange_total'] as num?)?.toDouble() ?? 0,
      netSettlement: (map['net_settlement'] as num?)?.toDouble() ?? 0,
      refundMethod: map['refund_method'] as String? ?? 'Cash',
      reason: map['reason'] as String? ?? '',
      customerName: map['customer_name'] as String? ?? '',
      customerPhone: map['customer_phone'] as String? ?? '',
      staffId: map['staff_id'] as String? ?? '',
      staffName: map['staff_name'] as String? ?? '',
      pointsReversed: (map['points_reversed'] as num?)?.toInt() ?? 0,
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  String toString() =>
      'ReturnModel($type, invoice: $originalInvoice, refund: $refundAmount, items: ${returnedItems.length})';
}
