import 'package:flutter/foundation.dart';

/// Client-side rate limiter for API protection
/// Prevents brute force login, rapid-fire sync, and excessive API calls
class RateLimiter {
  final int maxAttempts;
  final Duration window;
  final Duration lockoutDuration;

  final List<DateTime> _attempts = [];
  DateTime? _lockedUntil;

  RateLimiter({
    required this.maxAttempts,
    required this.window,
    this.lockoutDuration = const Duration(minutes: 1),
  });

  /// Check if action is allowed (not rate-limited)
  bool get isAllowed {
    _cleanupExpired();
    if (_lockedUntil != null && DateTime.now().isBefore(_lockedUntil!)) {
      return false;
    }
    return _attempts.length < maxAttempts;
  }

  /// Remaining seconds until lockout expires
  int get lockoutRemainingSeconds {
    if (_lockedUntil == null) return 0;
    final remaining = _lockedUntil!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// Record an attempt. Returns true if allowed, false if rate-limited.
  bool recordAttempt() {
    _cleanupExpired();

    // Check if currently locked out
    if (_lockedUntil != null && DateTime.now().isBefore(_lockedUntil!)) {
      debugPrint('🚫 Rate limited — locked for ${lockoutRemainingSeconds}s');
      return false;
    }

    // Clear lockout if expired
    _lockedUntil = null;

    _attempts.add(DateTime.now());

    if (_attempts.length > maxAttempts) {
      _lockedUntil = DateTime.now().add(lockoutDuration);
      debugPrint('🔒 Rate limit exceeded — locked for ${lockoutDuration.inSeconds}s');
      return false;
    }

    return true;
  }

  /// Reset after successful action (e.g., successful login)
  void reset() {
    _attempts.clear();
    _lockedUntil = null;
  }

  void _cleanupExpired() {
    final cutoff = DateTime.now().subtract(window);
    _attempts.removeWhere((t) => t.isBefore(cutoff));
  }
}

/// Throttle: ensures a function runs at most once per [interval]
class Throttle {
  final Duration interval;
  DateTime? _lastRun;

  Throttle({required this.interval});

  /// Returns true if enough time has passed since last execution
  bool canRun() {
    if (_lastRun == null) return true;
    return DateTime.now().difference(_lastRun!) >= interval;
  }

  /// Mark as just executed
  void markRun() {
    _lastRun = DateTime.now();
  }

  /// Execute [action] only if throttle allows
  Future<T?> run<T>(Future<T> Function() action) async {
    if (!canRun()) {
      debugPrint('⏳ Throttled — skipping (interval: ${interval.inSeconds}s)');
      return null;
    }
    markRun();
    return await action();
  }
}
