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

  /// Parse DateTime ensuring LOCAL timezone (fixes UTC/IST mismatch)
  static DateTime _parseLocal(String s) {
    final dt = DateTime.parse(s);
    return dt.isUtc ? dt.toLocal() : dt;
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    final clockOut = map['clock_out_time'] as String? ?? '';
    final clockIn = _parseLocal(map['clock_in_time'] as String);
    final clockOutDt = clockOut.isNotEmpty ? DateTime.tryParse(clockOut) : null;
    final clockOutLocal = clockOutDt != null ? (clockOutDt.isUtc ? clockOutDt.toLocal() : clockOutDt) : null;

    // Recalculate hours safely (never negative)
    double hours = (map['total_hours'] as num?)?.toDouble() ?? 0;
    if (clockOutLocal != null) {
      final calc = clockOutLocal.difference(clockIn).inMinutes / 60.0;
      hours = calc < 0 ? 0 : double.parse(calc.toStringAsFixed(2));
    }

    return AttendanceModel(
      id: map['id'] as String,
      staffId: map['staff_id'] as String,
      staffName: map['staff_name'] as String? ?? '',
      clockInTime: clockIn,
      clockOutTime: clockOutLocal,
      totalHours: hours,
      date: map['date'] as String? ?? '',
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      createdAt: _parseLocal(map['created_at'] as String),
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
