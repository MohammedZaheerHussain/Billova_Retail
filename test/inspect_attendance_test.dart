import 'package:flutter_test/flutter_test.dart';
import 'package:skywalk_billing/data/models/attendance_model.dart';

void main() {
  group('Attendance Tests', () {
    test('AttendanceModel parses local timestamps and calculates duration correctly', () {
      final map = {
        'id': 'test-1',
        'staff_id': 'staff-123',
        'staff_name': 'Aaquib',
        'clock_in_time': '2026-08-14T10:00:00.000',
        'clock_out_time': '2026-08-14T18:30:00.000',
        'total_hours': 8.5,
        'date': '2026-08-14',
        'is_deleted': 0,
        'created_at': '2026-08-14T10:00:00.000',
      };

      final model = AttendanceModel.fromMap(map);
      expect(model.id, 'test-1');
      expect(model.staffName, 'Aaquib');
      expect(model.date, '2026-08-14');
      expect(model.totalHours, 8.5);
      expect(model.isOpen, false);
    });

    test('AttendanceModel handles open shifts (null clockOutTime)', () {
      final map = {
        'id': 'test-2',
        'staff_id': 'staff-123',
        'staff_name': 'Aaquib',
        'clock_in_time': '2026-08-14T10:00:00.000+00:00',
        'clock_out_time': '',
        'total_hours': 0,
        'date': '2026-08-14',
        'is_deleted': false,
        'created_at': '2026-08-14T10:00:00.000+00:00',
      };

      final model = AttendanceModel.fromMap(map);
      expect(model.isOpen, true);
      expect(model.clockOutTime, isNull);
    });
  });
}
