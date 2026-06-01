import 'dart:convert';

class VendorModel {
  final String id;
  final String name;
  final String phone;
  final String notes; // Free-form notes about the vendor
  final double balance; // Outstanding amount owed TO vendor (udhaar)
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  VendorModel({
    required this.id,
    required this.name,
    this.phone = '',
    this.notes = '',
    this.balance = 0,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'notes': notes,
      'balance': balance,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory VendorModel.fromMap(Map<String, dynamic> map) {
    return VendorModel(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: (map['phone'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  VendorModel copyWith({
    String? name,
    String? phone,
    String? notes,
    double? balance,
    bool? isDeleted,
    DateTime? updatedAt,
  }) {
    return VendorModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      balance: balance ?? this.balance,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory VendorModel.fromJson(String source) => VendorModel.fromMap(jsonDecode(source));

  @override
  String toString() => 'VendorModel(id: $id, name: $name, balance: $balance)';
}
