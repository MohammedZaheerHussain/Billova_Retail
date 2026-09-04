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
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  bool get isOpen => clockOutTime == null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'staff_id': staffId,
      'staff_name': staffName,
      'clock_in_time': clockInTime.toIso8601String(),
      'clock_out_time': clockOutTime?.toIso8601String(),
      'total_hours': totalHours,
      'date': date.length >= 10 ? date.substring(0, 10) : date,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Strip timezone markers and parse as LOCAL time.
  /// Reason: DateTime.now().toUtc() stores local IST, toIso8601String() has no offset,
  /// but Supabase adds 'Z' (UTC marker). We must strip it to avoid double-shift.
  static DateTime _parseAsLocal(String s) {
    if (s.isEmpty) return DateTime.now();
    try {
      final stripped = s
          .replaceAll('Z', '')
          .replaceFirst(RegExp(r'[+-]\d{2}:\d{2}$'), '')
          .replaceFirst(RegExp(r'[+-]\d{4}$'), '');
      return DateTime.parse(stripped);
    } catch (_) {
      return DateTime.tryParse(s) ?? DateTime.now();
    }
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    final clockInStr = map['clock_in_time']?.toString() ?? '';
    final clockIn = clockInStr.isNotEmpty && clockInStr != 'null'
        ? _parseAsLocal(clockInStr)
        : DateTime.now();

    final clockOutStr = map['clock_out_time']?.toString() ?? '';
    DateTime? clockOut;
    if (clockOutStr.isNotEmpty && clockOutStr != 'null') {
      clockOut = _parseAsLocal(clockOutStr);
    }

    // Calculate hours safely — supports overnight shifts
    double hours = (map['total_hours'] as num?)?.toDouble() ?? 0;
    if (clockOut != null) {
      var diff = clockOut.difference(clockIn);
      // Overnight shift: clockOut appears before clockIn (e.g., in 9PM → out 6AM)
      if (diff.isNegative) {
        clockOut = clockOut.add(const Duration(days: 1));
        diff = clockOut.difference(clockIn);
      }
      hours = diff.isNegative ? 0 : double.parse((diff.inMinutes / 60.0).toStringAsFixed(2));
    }

    final createdAtStr = map['created_at']?.toString() ?? '';

    String dateVal = map['date']?.toString() ?? '';
    if (dateVal.length >= 10) {
      dateVal = dateVal.substring(0, 10);
    } else {
      dateVal = '${clockIn.year}-${clockIn.month.toString().padLeft(2, '0')}-${clockIn.day.toString().padLeft(2, '0')}';
    }

    return AttendanceModel(
      id: map['id']?.toString() ?? '',
      staffId: map['staff_id']?.toString() ?? '',
      staffName: map['staff_name']?.toString() ?? '',
      clockInTime: clockIn,
      clockOutTime: clockOut,
      totalHours: hours,
      date: dateVal,
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      createdAt: createdAtStr.isNotEmpty && createdAtStr != 'null'
          ? _parseAsLocal(createdAtStr)
          : clockIn,
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
