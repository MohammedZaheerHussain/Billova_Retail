import 'dart:convert';

class SaleItem {
  final String itemId;
  final String name;
  final double price;
  final int quantity;
  final double total;

  SaleItem({
    required this.itemId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.total,
  });

  Map<String, dynamic> toMap() => {
        'item_id': itemId,
        'name': name,
        'price': price,
        'quantity': quantity,
        'total': total,
      };

  factory SaleItem.fromMap(Map<String, dynamic> map) => SaleItem(
        itemId: map['item_id'] as String,
        name: map['name'] as String,
        price: (map['price'] as num).toDouble(),
        quantity: (map['quantity'] as num).toInt(),
        total: (map['total'] as num).toDouble(),
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
  final String paymentMode;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String staffId;
  final String staffName;

  SaleModel({
    required this.id,
    required this.invoiceNumber,
    this.customerName = '',
    this.customerPhone = '',
    required this.items,
    required this.subtotal,
    this.discount = 0,
    required this.total,
    this.paymentMode = 'Cash',
    this.staffId = '',
    this.staffName = '',
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);
  double get discountPercent => subtotal > 0 ? (discount / subtotal) * 100 : 0;

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
      'payment_mode': paymentMode,
      'staff_id': staffId,
      'staff_name': staffName,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
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
      paymentMode: map['payment_mode'] as String? ?? 'Cash',
      staffId: map['staff_id'] as String? ?? '',
      staffName: map['staff_name'] as String? ?? '',
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  SaleModel copyWith({
    String? customerName,
    String? customerPhone,
    List<SaleItem>? items,
    double? subtotal,
    double? discount,
    double? total,
    String? paymentMode,
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
      paymentMode: paymentMode ?? this.paymentMode,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() => 'SaleModel($invoiceNumber, total: $total, items: ${items.length})';
}
