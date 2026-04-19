import 'dart:convert';

class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final int totalOrders;
  final double totalSpent;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomerModel({
    required this.id,
    required this.name,
    this.phone = '',
    this.totalOrders = 0,
    this.totalSpent = 0,
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
    bool? isDeleted,
    DateTime? updatedAt,
  }) {
    return CustomerModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      totalOrders: totalOrders ?? this.totalOrders,
      totalSpent: totalSpent ?? this.totalSpent,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  @override
  String toString() => 'CustomerModel(name: $name, orders: $totalOrders, spent: $totalSpent)';
}
