import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../data/local/db_helper.dart';
import '../data/remote/supabase_service.dart';
import '../data/models/staff_model.dart';
import '../data/models/attendance_model.dart';

class StaffProvider extends ChangeNotifier {
  final DBHelper _db = DBHelper.instance;
  final SupabaseService _supabase = SupabaseService.instance;
  final _uuid = const Uuid();

  List<StaffModel> _staff = [];
  List<AttendanceModel> _todayAttendance = [];
  StaffModel? _currentStaff; // Currently logged-in staff
  bool _isLoading = false;

  // ─── Getters ───
  List<StaffModel> get staff => _staff;
  List<StaffModel> get activeStaff => _staff.where((s) => s.isActive).toList();
  List<AttendanceModel> get todayAttendance => _todayAttendance;
  StaffModel? get currentStaff => _currentStaff;
  bool get isLoading => _isLoading;
  bool get isStaffLoggedIn => _currentStaff != null;
  bool get isAdmin => _currentStaff?.isAdmin ?? true; // Default admin if no staff system
  String get currentStaffName => _currentStaff?.name ?? 'Admin';
  String get currentStaffRole => _currentStaff?.role.toUpperCase() ?? 'ADMIN';
  String? get currentStaffId => _currentStaff?.id;

  String get _todayDate => DateTime.now().toIso8601String().substring(0, 10);

  // ─── Session Persistence Keys ───
  static const _keyStaffId = 'staff_session_id';
  static const _keyStaffName = 'staff_session_name';
  static const _keyUserType = 'staff_session_type'; // 'admin' | 'staff'

  // ─── Staff CRUD ───

  Future<void> loadStaff() async {
    _isLoading = true;
    notifyListeners();

    try {
      final maps = await _db.query(
        'staff',
        where: 'is_deleted = 0',
        orderBy: 'name ASC',
      );
      _staff = maps.map((m) => StaffModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Failed to load staff: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addStaff({
    required String username,
    required String name,
    required String pin,
    String role = 'staff',
  }) async {
    // Check unique username
    final exists = _staff.any((s) => s.username.toLowerCase() == username.toLowerCase());
    if (exists) return false;

    try {
      final member = StaffModel(
        id: _uuid.v4(),
        username: username,
        name: name,
        pin: pin,
        role: role,
      );

      await _db.insert('staff', member.toMap());

      if (kIsWeb) {
        await _supabase.syncRecord('staff', member.id, 'insert', member.toMap());
      } else {
        _supabase.syncRecord('staff', member.id, 'insert', member.toMap());
      }

      _staff.add(member);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to add staff: $e');
      return false;
    }
  }

  Future<bool> updateStaff(StaffModel member) async {
    try {
      final updated = member.copyWith(updatedAt: DateTime.now());
      await _db.update('staff', updated.toMap(), updated.id);

      if (kIsWeb) {
        await _supabase.syncRecord('staff', updated.id, 'update', updated.toMap());
      } else {
        _supabase.syncRecord('staff', updated.id, 'update', updated.toMap());
      }

      final idx = _staff.indexWhere((s) => s.id == updated.id);
      if (idx != -1) _staff[idx] = updated;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to update staff: $e');
      return false;
    }
  }

  Future<bool> deleteStaff(String id) async {
    try {
      final member = _staff.firstWhere((s) => s.id == id);
      final deleted = member.copyWith(isDeleted: true);
      await _db.update('staff', deleted.toMap(), deleted.id);

      if (kIsWeb) {
        await _supabase.syncRecord('staff', deleted.id, 'delete', deleted.toMap());
      } else {
        _supabase.syncRecord('staff', deleted.id, 'delete', deleted.toMap());
      }

      _staff.removeWhere((s) => s.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to delete staff: $e');
      return false;
    }
  }

  // ─── Staff Login (Username + PIN) ───

  /// Validate username + PIN, set session, auto clock-in
  Future<String?> loginStaff(String username, String pin) async {
    // Ensure staff are loaded
    if (_staff.isEmpty) await loadStaff();

    final match = _staff.cast<StaffModel?>().firstWhere(
      (s) => s!.username.toLowerCase() == username.toLowerCase() && s.pin == pin && s.isActive,
      orElse: () => null,
    );

    if (match == null) return 'Invalid username or PIN';

    _currentStaff = match;
    debugPrint('👨‍💼 Staff login: ${match.name} (${match.role})');

    // Persist session
    await _saveSession(match);

    // Auto clock-in (prevent duplicates)
    await _autoClockIn();

    notifyListeners();
    return null; // null = success
  }

  /// Restore staff session from shared_preferences (call on app start)
  Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final staffId = prefs.getString(_keyStaffId);
      final userType = prefs.getString(_keyUserType);

      if (staffId == null || userType != 'staff') {
        debugPrint('🔑 No staff session to restore');
        return false;
      }

      // Ensure staff list is loaded
      if (_staff.isEmpty) await loadStaff();

      final match = _staff.cast<StaffModel?>().firstWhere(
        (s) => s!.id == staffId && s.isActive,
        orElse: () => null,
      );

      if (match != null) {
        _currentStaff = match;
        debugPrint('🔄 Staff session restored: ${match.name}');
        notifyListeners();
        return true;
      } else {
        // Staff was deleted or deactivated — clear stale session
        await _clearSession();
        return false;
      }
    } catch (e) {
      debugPrint('Failed to restore staff session: $e');
      return false;
    }
  }

  /// Log out current staff → clockOut → clear session
  Future<void> logoutStaff() async {
    if (_currentStaff != null) {
      debugPrint('👋 Staff logout: ${_currentStaff!.name}');

      // Auto clock-out if clocked in
      final openShift = getOpenShift(_currentStaff!.id);
      if (openShift != null) {
        await clockOut();
        debugPrint('   ⏱️ Auto clocked out');
      }
    }

    _currentStaff = null;
    await _clearSession();
    notifyListeners();
  }

  /// Save session to SharedPreferences
  Future<void> _saveSession(StaffModel staff) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyStaffId, staff.id);
      await prefs.setString(_keyStaffName, staff.name);
      await prefs.setString(_keyUserType, 'staff');
      debugPrint('   💾 Session saved');
    } catch (e) {
      debugPrint('Failed to save staff session: $e');
    }
  }

  /// Clear persisted session
  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyStaffId);
      await prefs.remove(_keyStaffName);
      await prefs.remove(_keyUserType);
    } catch (e) {
      debugPrint('Failed to clear staff session: $e');
    }
  }

  // ─── Attendance ───

  Future<void> loadTodayAttendance() async {
    try {
      final maps = await _db.query(
        'attendance',
        where: 'date = ? AND is_deleted = 0',
        whereArgs: [_todayDate],
        orderBy: 'clock_in_time DESC',
      );
      _todayAttendance = maps.map((m) => AttendanceModel.fromMap(m)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load attendance: $e');
    }
  }

  /// Check if staff has an open shift (clocked in, no clock out)
  AttendanceModel? getOpenShift(String staffId) {
    try {
      return _todayAttendance.firstWhere(
        (a) => a.staffId == staffId && a.isOpen,
      );
    } catch (_) {
      return null;
    }
  }

  /// Auto clock-in: only if NOT already clocked in today
  Future<void> _autoClockIn() async {
    if (_currentStaff == null) return;

    // Load attendance first to check
    await loadTodayAttendance();

    // Check for existing open shift — prevent duplicate clock-in
    final openShift = getOpenShift(_currentStaff!.id);
    if (openShift != null) {
      debugPrint('   ⏱️ Already clocked in — skipping auto clock-in');
      return;
    }

    // Also check if already clocked in and out today (re-login scenario)
    final todayShifts = _todayAttendance.where((a) => a.staffId == _currentStaff!.id).toList();
    if (todayShifts.isNotEmpty) {
      debugPrint('   ⏱️ Has existing attendance today — creating new shift');
    }

    await clockIn();
    debugPrint('   ⏱️ Auto clocked in');
  }

  /// Clock in current staff
  Future<bool> clockIn() async {
    if (_currentStaff == null) return false;

    // Prevent double clock-in
    final openShift = getOpenShift(_currentStaff!.id);
    if (openShift != null) return false;

    try {
      final now = DateTime.now();
      final attendance = AttendanceModel(
        id: _uuid.v4(),
        staffId: _currentStaff!.id,
        staffName: _currentStaff!.name,
        clockInTime: now,
        date: _todayDate,
      );

      await _db.insert('attendance', attendance.toMap());

      if (kIsWeb) {
        await _supabase.syncRecord('attendance', attendance.id, 'insert', attendance.toMap());
      } else {
        _supabase.syncRecord('attendance', attendance.id, 'insert', attendance.toMap());
      }

      _todayAttendance.insert(0, attendance);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to clock in: $e');
      return false;
    }
  }

  /// Clock out current staff
  Future<bool> clockOut() async {
    if (_currentStaff == null) return false;

    final openShift = getOpenShift(_currentStaff!.id);
    if (openShift == null) return false;

    try {
      final now = DateTime.now();
      final duration = now.difference(openShift.clockInTime);
      final hours = duration.inMinutes / 60.0;

      final updated = openShift.copyWith(
        clockOutTime: now,
        totalHours: double.parse(hours.toStringAsFixed(2)),
      );

      await _db.update('attendance', updated.toMap(), updated.id);

      if (kIsWeb) {
        await _supabase.syncRecord('attendance', updated.id, 'update', updated.toMap());
      } else {
        _supabase.syncRecord('attendance', updated.id, 'update', updated.toMap());
      }

      final idx = _todayAttendance.indexWhere((a) => a.id == updated.id);
      if (idx != -1) _todayAttendance[idx] = updated;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to clock out: $e');
      return false;
    }
  }

  /// Check if current staff is currently clocked in
  bool get isClockedIn {
    if (_currentStaff == null) return false;
    return getOpenShift(_currentStaff!.id) != null;
  }

  // ─── Role-Based Access ───

  /// Modules accessible by staff (non-admin) role
  static const List<String> _staffAllowedModules = [
    'Inventory',
    'Sales Terminal',
    'Customers',
    'Bill History',
  ];

  /// Check if current user can access a module
  bool canAccess(String moduleLabel) {
    if (isAdmin || _currentStaff == null) return true;
    return _staffAllowedModules.contains(moduleLabel);
  }
}
