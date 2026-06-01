import 'dart:convert';

class CategoryModel {
  final String id;
  final String name;
  final bool requiresSize;
  final bool requiresColor;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  CategoryModel({
    required this.id,
    required this.name,
    this.requiresSize = false,
    this.requiresColor = false,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'requires_size': requiresSize ? 1 : 0,
      'requires_color': requiresColor ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      requiresSize: map['requires_size'] == 1 || map['requires_size'] == true,
      requiresColor: map['requires_color'] == 1 || map['requires_color'] == true,
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now().toUtc(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now().toUtc(),
    );
  }

  CategoryModel copyWith({
    String? name,
    bool? requiresSize,
    bool? requiresColor,
    bool? isDeleted,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      id: id,
      name: name ?? this.name,
      requiresSize: requiresSize ?? this.requiresSize,
      requiresColor: requiresColor ?? this.requiresColor,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory CategoryModel.fromJson(String source) =>
      CategoryModel.fromMap(jsonDecode(source));

  @override
  String toString() =>
      'CategoryModel(id: $id, name: $name, size: $requiresSize, color: $requiresColor)';
}
