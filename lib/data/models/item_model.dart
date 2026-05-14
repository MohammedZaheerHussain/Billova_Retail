import 'dart:convert';

class ItemModel {
  final String id;
  final String name;
  final String vendor;
  final String barcode;
  final String category;
  final String size;
  final String color;
  final String storageLocation;
  final double price;
  final double costPrice;
  final double originalPrice;     // MRP before clearance discount (0 = not a clearance item)
  final String parentItemId;      // Links clearance copy → original item ('' = not a copy)
  final double gstRate;          // GST percentage (0, 5, 12, 18, 28)
  final int quantity;
  final int lowStockThreshold;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  ItemModel({
    required this.id,
    required this.name,
    this.vendor = '',
    this.barcode = '',
    this.category = '',
    this.size = '',
    this.color = '',
    this.storageLocation = '',
    required this.price,
    this.originalPrice = 0,
    this.parentItemId = '',
    this.costPrice = 0,
    this.gstRate = 0,
    this.quantity = 0,
    this.lowStockThreshold = 5,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isLowStock => quantity > 0 && quantity <= lowStockThreshold;
  bool get isOutOfStock => quantity <= 0;
  double get profit => price - costPrice;
  double get profitMargin => costPrice > 0 ? ((price - costPrice) / costPrice) * 100 : 0;
  double get stockValue => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'vendor': vendor,
      'barcode': barcode,
      'category': category,
      'size': size,
      'color': color,
      'storage_location': storageLocation,
      'price': price,
      'original_price': originalPrice,
      'parent_item_id': parentItemId,
      'cost_price': costPrice,
      'gst_rate': gstRate,
      'quantity': quantity,
      'low_stock_threshold': lowStockThreshold,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      id: map['id'] as String,
      name: map['name'] as String,
      vendor: (map['vendor'] as String?) ?? '',
      barcode: (map['barcode'] as String?) ?? '',
      category: (map['category'] as String?) ?? '',
      size: (map['size'] as String?) ?? '',
      color: (map['color'] as String?) ?? '',
      storageLocation: (map['storage_location'] as String?) ?? '',
      price: (map['price'] as num).toDouble(),
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0,
      gstRate: (map['gst_rate'] as num?)?.toDouble() ?? 0,
      originalPrice: (map['original_price'] as num?)?.toDouble() ?? 0,
      parentItemId: (map['parent_item_id'] as String?) ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      lowStockThreshold: (map['low_stock_threshold'] as num?)?.toInt() ?? 5,
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  ItemModel copyWith({
    String? name,
    String? vendor,
    String? barcode,
    String? category,
    String? size,
    String? color,
    String? storageLocation,
    double? price,
    double? originalPrice,
    String? parentItemId,
    double? costPrice,
    double? gstRate,
    int? quantity,
    int? lowStockThreshold,
    bool? isDeleted,
    DateTime? updatedAt,
  }) {
    return ItemModel(
      id: id,
      name: name ?? this.name,
      vendor: vendor ?? this.vendor,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      size: size ?? this.size,
      color: color ?? this.color,
      storageLocation: storageLocation ?? this.storageLocation,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      gstRate: gstRate ?? this.gstRate,
      originalPrice: originalPrice ?? this.originalPrice,
      parentItemId: parentItemId ?? this.parentItemId,
      quantity: quantity ?? this.quantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory ItemModel.fromJson(String source) => ItemModel.fromMap(jsonDecode(source));

  @override
  String toString() => 'ItemModel(id: $id, name: $name, vendor: $vendor, barcode: $barcode, price: $price, qty: $quantity)';
}
