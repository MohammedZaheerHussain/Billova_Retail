import 'dart:convert';

class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final int totalOrders;
  final double totalSpent;
  final int loyaltyPoints;
  final DateTime? lastPurchaseDate;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomerModel({
    required this.id,
    required this.name,
    this.phone = '',
    this.totalOrders = 0,
    this.totalSpent = 0,
    this.loyaltyPoints = 0,
    this.lastPurchaseDate,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'total_orders': totalOrders,
      'total_spent': totalSpent,
      'loyalty_points': loyaltyPoints,
      'last_purchase_date': lastPurchaseDate?.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      totalOrders: (map['total_orders'] as num?)?.toInt() ?? 0,
      totalSpent: (map['total_spent'] as num?)?.toDouble() ?? 0,
      loyaltyPoints: (map['loyalty_points'] as num?)?.toInt() ?? 0,
      lastPurchaseDate: map['last_purchase_date'] != null
          ? DateTime.tryParse(map['last_purchase_date'] as String)
          : null,
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  CustomerModel copyWith({
    String? name,
    String? phone,
    int? totalOrders,
    double? totalSpent,
    int? loyaltyPoints,
    DateTime? lastPurchaseDate,
    bool? isDeleted,
    DateTime? updatedAt,
  }) {
    return CustomerModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      totalOrders: totalOrders ?? this.totalOrders,
      totalSpent: totalSpent ?? this.totalSpent,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  @override
  String toString() => 'CustomerModel(name: $name, orders: $totalOrders, spent: $totalSpent)';
}
