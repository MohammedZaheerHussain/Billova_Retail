import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/remote/supabase_service.dart';
import '../data/local/db_helper.dart';
import '../core/utils/rate_limiter.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabase = SupabaseService.instance;

  AuthStatus _status = AuthStatus.initial;
  String _errorMessage = '';
  bool _isSyncing = false;
  String _userType = 'admin'; // 'admin' | 'staff'

  // ─── Rate Limiting ───
  // Login: max 5 attempts per 2 minutes, then 60s lockout
  final _loginLimiter = RateLimiter(
    maxAttempts: 5,
    window: const Duration(minutes: 2),
    lockoutDuration: const Duration(seconds: 60),
  );
  // Sync: max once per 5 seconds
  final _syncThrottle = Throttle(interval: const Duration(seconds: 5));

  AuthStatus get status => _status;
  String get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isSyncing => _isSyncing;
  String? get userEmail => _supabase.currentUser?.email;
  String get userType => _userType;
  bool get isAdminSession => _userType == 'admin';

  /// Check if user has an existing session (admin Supabase session)
  Future<void> checkSession() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final session = await _supabase.recoverSession();
      if (session != null && _supabase.isLoggedIn) {
        _status = AuthStatus.authenticated;

        // Restore user type from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        _userType = prefs.getString('staff_session_type') ?? 'admin';

        // NOTE: Do NOT pull data here — app_shell._loadAllData handles pull + load
        debugPrint('✅ Session recovered (type: $_userType) — data pull will happen in app_shell');
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  /// Sign in with email/password (Admin only)
  Future<bool> signIn(String email, String password) async {
    // Rate limit check
    if (!_loginLimiter.isAllowed) {
      _status = AuthStatus.error;
      _errorMessage = 'Too many login attempts. Try again in ${_loginLimiter.lockoutRemainingSeconds}s';
      notifyListeners();
      return false;
    }

    _status = AuthStatus.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      // Record attempt BEFORE trying
      _loginLimiter.recordAttempt();

      await _supabase.signIn(email, password);
      _status = AuthStatus.authenticated;
      _userType = 'admin';

      // Successful login — reset rate limiter
      _loginLimiter.reset();

      // Save session type
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('staff_session_type', 'admin');

      notifyListeners();

      // Pull all data after login (background, non-blocking)
      _syncInBackground();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _parseError(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Staff login — does NOT use Supabase Auth, reuses existing admin session
  /// Called after StaffProvider.loginStaff() validates credentials
  Future<bool> staffLogin() async {
    // Staff does NOT authenticate with Supabase
    // Just mark session type
    _userType = 'staff';
    _status = AuthStatus.authenticated;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('staff_session_type', 'staff');

    notifyListeners();
    return true;
  }

  /// Sign up with email/password (Admin only)
  Future<bool> signUp(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final response = await _supabase.signUp(email, password);

      // Supabase may require email confirmation
      if (response.user != null && response.session != null) {
        _status = AuthStatus.authenticated;
        _userType = 'admin';
      } else if (response.user != null) {
        // User created but needs email confirmation
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'Account created! Please check your email and confirm, then log in.';
      } else {
        _status = AuthStatus.error;
        _errorMessage = 'Sign up failed. Please try again.';
      }

      notifyListeners();
      return _status == AuthStatus.authenticated;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _parseError(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Sign out — navigates to login, but keeps Supabase session alive
  /// The Supabase session is a BUSINESS session (not per-user)
  /// Staff needs it to sync data even when admin isn't present
  Future<void> signOut() async {
    // Do NOT call _supabase.signOut() — keep business session alive
    // Staff needs the Supabase connection to pull/sync data

    _status = AuthStatus.unauthenticated;
    _userType = 'admin';
    _isSyncing = false;

    // Clear session type
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('staff_session_type');

    notifyListeners();
  }

  /// Full sign out — destroys Supabase session + wipes ALL local data.
  /// Ensures the next user who logs in sees a clean, empty app.
  /// Only use this from Settings or when switching user accounts.
  Future<void> fullSignOut() async {
    // ─── STEP 1: Wipe all local DB data (in-memory on web) ───
    try {
      final db = DBHelper.instance;
      await db.clearAllData();
      debugPrint('🧹 Local DB cleared');
    } catch (e) {
      debugPrint('⚠️ Failed to clear local DB: $e');
    }

    // ─── STEP 2: Clear SharedPreferences BUT preserve theme ───
    try {
      final prefs = await SharedPreferences.getInstance();
      // Save theme before clearing — theme is a device preference, not user data
      final savedTheme = prefs.getString('app_theme_mode');
      await prefs.clear();
      // Restore theme so it survives user switch
      if (savedTheme != null) {
        await prefs.setString('app_theme_mode', savedTheme);
      }
      debugPrint('🧹 SharedPreferences cleared (theme preserved)');
    } catch (e) {
      debugPrint('⚠️ Failed to clear SharedPreferences: $e');
    }

    // ─── STEP 3: Destroy Supabase session ───
    try {
      await _supabase.signOut();
    } catch (_) {}

    _status = AuthStatus.unauthenticated;
    _userType = 'admin';
    _isSyncing = false;

    notifyListeners();
  }

  /// Set error message (used by login screen for staff errors)
  void setError(String message) {
    _errorMessage = message;
    _status = AuthStatus.error;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _errorMessage = '';
    if (_status == AuthStatus.error) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Background sync — pull data + process sync queue (throttled)
  Future<void> _syncInBackground() async {
    // Throttle: max once per 5 seconds
    if (!_syncThrottle.canRun()) {
      debugPrint('⏳ Sync throttled — skipping');
      return;
    }
    _syncThrottle.markRun();

    _isSyncing = true;
    notifyListeners();

    try {
      await _supabase.pullAllData();
    } catch (e) {
      debugPrint('Background pull error: $e');
    }

    try {
      await _supabase.processSyncQueue();
    } catch (e) {
      debugPrint('Sync queue error: $e');
    }

    _isSyncing = false;
    notifyListeners();
  }

  /// Manual retry sync (also throttled)
  Future<void> retrySync() async {
    _syncThrottle.markRun(); // Force allow manual retry
    await _syncInBackground();
  }

  String _parseError(String error) {
    if (error.contains('Invalid login')) return 'Invalid email or password';
    if (error.contains('Email not confirmed')) return 'Please verify your email first';
    if (error.contains('User already registered')) return 'Account already exists. Try logging in.';
    if (error.contains('network')) return 'Network error. Check your connection.';
    if (error.contains('weak_password')) return 'Password too weak. Use 6+ characters.';
    if (error.contains('invalid_email')) return 'Invalid email address.';
    return 'Something went wrong. Please try again.';
  }
}
