import 'dart:convert';

class AttendanceModel {
  final String id;
  final String staffId;
  final String staffName;
  final DateTime clockInTime;
  final DateTime? clockOutTime;
  final double totalHours;
  final String date; // YYYY-MM-DD
  final bool isDeleted;
  final DateTime createdAt;

  AttendanceModel({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.clockInTime,
    this.clockOutTime,
    this.totalHours = 0,
    required this.date,
    this.isDeleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isOpen => clockOutTime == null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'staff_id': staffId,
      'staff_name': staffName,
      'clock_in_time': clockInTime.toIso8601String(),
      'clock_out_time': clockOutTime?.toIso8601String() ?? '',
      'total_hours': totalHours,
      'date': date,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    final clockOut = map['clock_out_time'] as String? ?? '';
    return AttendanceModel(
      id: map['id'] as String,
      staffId: map['staff_id'] as String,
      staffName: map['staff_name'] as String? ?? '',
      clockInTime: DateTime.parse(map['clock_in_time'] as String),
      clockOutTime: clockOut.isNotEmpty ? DateTime.tryParse(clockOut) : null,
      totalHours: (map['total_hours'] as num?)?.toDouble() ?? 0,
      date: map['date'] as String? ?? '',
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  AttendanceModel copyWith({
    DateTime? clockOutTime,
    double? totalHours,
  }) {
    return AttendanceModel(
      id: id,
      staffId: staffId,
      staffName: staffName,
      clockInTime: clockInTime,
      clockOutTime: clockOutTime ?? this.clockOutTime,
      totalHours: totalHours ?? this.totalHours,
      date: date,
      isDeleted: isDeleted,
      createdAt: createdAt,
    );
  }

  String toJson() => jsonEncode(toMap());

  @override
  String toString() =>
      'AttendanceModel(staff: $staffName, in: $clockInTime, out: $clockOutTime, hours: $totalHours)';
}
