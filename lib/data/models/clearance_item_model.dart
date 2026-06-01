/// Audit record tracking stock moved to clearance.
/// This table acts as the source of truth for clearance movements.
class ClearanceItemModel {
  final String id;
  final String originalItemId;   // The master inventory item we split from
  final String clearanceItemId;  // The new item created in items table
  final int quantity;            // How many units were moved
  final double originalPrice;    // MRP at the time of move
  final double clearancePrice;   // Discounted price set by user
  final String reason;           // e.g. Damaged, Slow Moving
  final String status;           // active | restored
  final DateTime createdAt;
  final DateTime updatedAt;

  ClearanceItemModel({
    required this.id,
    required this.originalItemId,
    required this.clearanceItemId,
    required this.quantity,
    required this.originalPrice,
    required this.clearancePrice,
    required this.reason,
    this.status = 'active',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  double get discountPercent =>
      originalPrice > 0 ? ((1 - clearancePrice / originalPrice) * 100).clamp(0, 100) : 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'original_item_id': originalItemId,
        'clearance_item_id': clearanceItemId,
        'quantity': quantity,
        'original_price': originalPrice,
        'clearance_price': clearancePrice,
        'reason': reason,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ClearanceItemModel.fromMap(Map<String, dynamic> map) {
    return ClearanceItemModel(
      id: map['id'] as String,
      originalItemId: map['original_item_id'] as String,
      clearanceItemId: map['clearance_item_id'] as String,
      quantity: (map['quantity'] as num).toInt(),
      originalPrice: (map['original_price'] as num).toDouble(),
      clearancePrice: (map['clearance_price'] as num).toDouble(),
      reason: (map['reason'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'active',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  ClearanceItemModel copyWith({
    int? quantity,
    double? clearancePrice,
    String? reason,
    String? status,
    DateTime? updatedAt,
  }) {
    return ClearanceItemModel(
      id: id,
      originalItemId: originalItemId,
      clearanceItemId: clearanceItemId,
      quantity: quantity ?? this.quantity,
      originalPrice: originalPrice,
      clearancePrice: clearancePrice ?? this.clearancePrice,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }
}
