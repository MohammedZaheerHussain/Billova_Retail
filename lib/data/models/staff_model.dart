import 'dart:convert';

class StaffModel {
  final String id;
  final String username;
  final String name;
  final String pin;
  final String role; // "admin" | "staff"
  final bool isActive;
  final bool isDeleted;
  final double monthlySaleTarget; // Monthly sale target in ₹
  final DateTime createdAt;
  final DateTime updatedAt;

  StaffModel({
    required this.id,
    required this.username,
    required this.name,
    required this.pin,
    this.role = 'staff',
    this.isActive = true,
    this.isDeleted = false,
    this.monthlySaleTarget = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isAdmin => role == 'admin';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'pin': pin,
      'role': role,
      'is_active': isActive ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'monthly_sale_target': monthlySaleTarget,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory StaffModel.fromMap(Map<String, dynamic> map) {
    return StaffModel(
      id: map['id'] as String,
      username: map['username'] as String? ?? '',
      name: map['name'] as String? ?? '',
      pin: map['pin'] as String? ?? '',
      role: map['role'] as String? ?? 'staff',
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      monthlySaleTarget: (map['monthly_sale_target'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  StaffModel copyWith({
    String? username,
    String? name,
    String? pin,
    String? role,
    bool? isActive,
    bool? isDeleted,
    double? monthlySaleTarget,
    DateTime? updatedAt,
  }) {
    return StaffModel(
      id: id,
      username: username ?? this.username,
      name: name ?? this.name,
      pin: pin ?? this.pin,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      monthlySaleTarget: monthlySaleTarget ?? this.monthlySaleTarget,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  @override
  String toString() => 'StaffModel(id: $id, username: $username, name: $name, role: $role)';
}
