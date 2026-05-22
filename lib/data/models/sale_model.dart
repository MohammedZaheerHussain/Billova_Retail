import 'dart:convert';

class SaleItem {
  final String itemId;
  final String name;
  final double price;
  final double costPrice;   // Purchase/cost price at time of sale (for profit calc)
  final int quantity;
  final double total;
  final double gstRate;     // GST % for this item (0/5/12/18/28)

  SaleItem({
    required this.itemId,
    required this.name,
    required this.price,
    this.costPrice = 0,
    required this.quantity,
    required this.total,
    this.gstRate = 0,
  });

  /// Gross profit for this line item: (selling_price - cost_price) * quantity
  double get profit => (price - costPrice) * quantity;
  /// GST amount for this line item
  double get gstAmount => total * gstRate / 100;
  /// Taxable value (item total before GST)
  double get taxableValue => total;

  Map<String, dynamic> toMap() => {
        'item_id': itemId,
        'name': name,
        'price': price,
        'cost_price': costPrice,
        'quantity': quantity,
        'total': total,
        'gst_rate': gstRate,
      };

  factory SaleItem.fromMap(Map<String, dynamic> map) => SaleItem(
        itemId: map['item_id'] as String,
        name: map['name'] as String,
        price: (map['price'] as num).toDouble(),
        costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0,
        quantity: (map['quantity'] as num).toInt(),
        total: (map['total'] as num).toDouble(),
        gstRate: (map['gst_rate'] as num?)?.toDouble() ?? 0,
      );
}

class SaleModel {
  final String id;
  final String invoiceNumber;
  final String customerName;
  final String customerPhone;
  final List<SaleItem> items;
  final double subtotal;
  final double discount;
  final double total;
  final double gstAmount;        // total GST across all items
  final double cgst;             // CGST (half of GST — same state)
  final double sgst;             // SGST (half of GST — same state)
  final String paymentMode;  // kept for backward compat / display
  final double cashAmount;   // actual cash collected
  final double upiAmount;    // actual UPI/card collected
  final double cardAmount;   // future: separate card channel
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String staffId;
  final String staffName;
  final double loyaltyDiscount;  // ₹ deducted via loyalty points
  final int pointsRedeemed;      // number of points used
  final int pointsEarned;        // number of points awarded
  final double dueAmount;        // unpaid portion (Udhar/credit)

  SaleModel({
    required this.id,
    required this.invoiceNumber,
    this.customerName = '',
    this.customerPhone = '',
    required this.items,
    required this.subtotal,
    this.discount = 0,
    required this.total,
    this.gstAmount = 0,
    this.cgst = 0,
    this.sgst = 0,
    this.paymentMode = 'Cash',
    this.cashAmount = 0,
    this.upiAmount = 0,
    this.cardAmount = 0,
    this.staffId = '',
    this.staffName = '',
    this.loyaltyDiscount = 0,
    this.pointsRedeemed = 0,
    this.pointsEarned = 0,
    this.dueAmount = 0,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);
  double get discountPercent => subtotal > 0 ? (discount / subtotal) * 100 : 0;
  bool get isUdhar => dueAmount > 0;

  /// Total cost of goods sold (sum of cost_price * quantity for each item)
  double get totalCostPrice => items.fold(0.0, (sum, item) => sum + (item.costPrice * item.quantity));

  /// Gross profit = sum of per-item profits - discount
  /// Per-item profit = (selling_price - cost_price) * quantity
  double get grossProfit => items.fold(0.0, (sum, item) => sum + item.profit) - discount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'items': jsonEncode(items.map((e) => e.toMap()).toList()),
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
      'gst_amount': gstAmount,
      'cgst': cgst,
      'sgst': sgst,
      'payment_mode': paymentMode,
      'cash_amount': cashAmount,
      'upi_amount': upiAmount,
      'card_amount': cardAmount,
      'staff_id': staffId,
      'staff_name': staffName,
      'loyalty_discount': loyaltyDiscount,
      'points_redeemed': pointsRedeemed,
      'points_earned': pointsEarned,
      'due_amount': dueAmount,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory SaleModel.fromMap(Map<String, dynamic> map) {
    final itemsData = map['items'];
    List<SaleItem> parsedItems;

    if (itemsData is String) {
      final decoded = jsonDecode(itemsData) as List;
      parsedItems = decoded.map((e) => SaleItem.fromMap(e as Map<String, dynamic>)).toList();
    } else if (itemsData is List) {
      parsedItems = itemsData.map((e) => SaleItem.fromMap(e as Map<String, dynamic>)).toList();
    } else {
      parsedItems = [];
    }

    return SaleModel(
      id: map['id'] as String,
      invoiceNumber: map['invoice_number'] as String,
      customerName: map['customer_name'] as String? ?? '',
      customerPhone: map['customer_phone'] as String? ?? '',
      items: parsedItems,
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num).toDouble(),
      gstAmount: (map['gst_amount'] as num?)?.toDouble() ?? 0,
      cgst: (map['cgst'] as num?)?.toDouble() ?? 0,
      sgst: (map['sgst'] as num?)?.toDouble() ?? 0,
      paymentMode: map['payment_mode'] as String? ?? 'Cash',
      // Payment split — backward compat: if new fields absent, derive from paymentMode
      cashAmount: (map['cash_amount'] as num?)?.toDouble() ?? (() {
        final mode = (map['payment_mode'] as String? ?? 'Cash').toLowerCase();
        final total = (map['total'] as num?)?.toDouble() ?? 0;
        return mode == 'cash' ? total : 0.0;
      })(),
      upiAmount: (map['upi_amount'] as num?)?.toDouble() ?? (() {
        final mode = (map['payment_mode'] as String? ?? 'Cash').toLowerCase();
        final total = (map['total'] as num?)?.toDouble() ?? 0;
        return (mode == 'upi' || mode == 'upi/card') ? total : 0.0;
      })(),
      cardAmount: (map['card_amount'] as num?)?.toDouble() ?? 0,
      staffId: map['staff_id'] as String? ?? '',
      staffName: map['staff_name'] as String? ?? '',
      loyaltyDiscount: (map['loyalty_discount'] as num?)?.toDouble() ?? 0,
      pointsRedeemed: (map['points_redeemed'] as num?)?.toInt() ?? 0,
      pointsEarned: (map['points_earned'] as num?)?.toInt() ?? 0,
      dueAmount: (map['due_amount'] as num?)?.toDouble() ?? 0,
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      createdAt: _parseTimestamp(map['created_at'] as String),
      updatedAt: _parseTimestamp(map['updated_at'] as String),
    );
  }

  SaleModel copyWith({
    String? customerName,
    String? customerPhone,
    List<SaleItem>? items,
    double? subtotal,
    double? discount,
    double? total,
    double? gstAmount,
    double? cgst,
    double? sgst,
    String? paymentMode,
    double? cashAmount,
    double? upiAmount,
    double? cardAmount,
    double? loyaltyDiscount,
    int? pointsRedeemed,
    int? pointsEarned,
    double? dueAmount,
    bool? isDeleted,
    DateTime? updatedAt,
  }) {
    return SaleModel(
      id: id,
      invoiceNumber: invoiceNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      gstAmount: gstAmount ?? this.gstAmount,
      cgst: cgst ?? this.cgst,
      sgst: sgst ?? this.sgst,
      paymentMode: paymentMode ?? this.paymentMode,
      cashAmount: cashAmount ?? this.cashAmount,
      upiAmount: upiAmount ?? this.upiAmount,
      cardAmount: cardAmount ?? this.cardAmount,
      staffId: staffId,
      staffName: staffName,
      loyaltyDiscount: loyaltyDiscount ?? this.loyaltyDiscount,
      pointsRedeemed: pointsRedeemed ?? this.pointsRedeemed,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      dueAmount: dueAmount ?? this.dueAmount,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  /// Parse timestamp consistently — handles both UTC (new) and local (old) formats.
  /// If string has 'Z' or '+' timezone info → parse as-is (UTC).
  /// If no timezone info → treat as LOCAL time (backward compat for old data).
  static DateTime _parseTimestamp(String s) {
    return DateTime.parse(s);
  }

  @override
  String toString() => 'SaleModel($invoiceNumber, total: $total, items: ${items.length})';
}
