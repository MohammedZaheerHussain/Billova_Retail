import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_version.dart';
import '../../data/models/app_version_model.dart';
import '../../data/remote/supabase_service.dart';

// Conditional web import
import 'dart:html' as html;

class AppUpdateResult {
  final bool hasUpdate;
  final AppVersionModel? versionInfo;
  final bool isForced;

  const AppUpdateResult({
    required this.hasUpdate,
    this.versionInfo,
    this.isForced = false,
  });
}

/// Service to handle in-app version checking, throttling, and updating
class AppUpdateService {
  static AppUpdateService? _instance;
  static AppUpdateService get instance => _instance ??= AppUpdateService._();

  AppUpdateService._();

  static const String _keyDismissedVersion = 'app_update_dismissed_version';
  static const String _keyDismissedTime = 'app_update_dismissed_time';
  static const Duration _dismissCooldown = Duration(hours: 6);

  /// Check if a newer version is available.
  /// If [isManual] is true, ignores dismissal cooldown.
  Future<AppUpdateResult> checkForUpdate({bool isManual = false}) async {
    try {
      AppVersionModel? remoteVersion;

      // 1. Fetch from hosted version.json (Vercel static endpoint)
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final String origin;
        if (kIsWeb && Uri.base.scheme.isNotEmpty && Uri.base.authority.isNotEmpty) {
          origin = '${Uri.base.scheme}://${Uri.base.authority}';
        } else {
          origin = AppVersion.productionUrl;
        }
        final uri = Uri.parse('$origin/version.json?t=$timestamp');

        final response = await http.get(
          uri,
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0',
          },
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            remoteVersion = AppVersionModel.fromJson(data);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Hosted version.json check error: $e');
      }

      // 2. Fall back to Supabase app_versions if hosted check failed
      if (remoteVersion == null) {
        try {
          final supabase = SupabaseService.instance;
          if (supabase.isLoggedIn) {
            final res = await supabase.client
                .from('app_versions')
                .select()
                .order('created_at', ascending: false)
                .limit(1);

            if (res.isNotEmpty) {
              remoteVersion = AppVersionModel.fromJson(Map<String, dynamic>.from(res.first));
            }
          }
        } catch (_) {}
      }

      if (remoteVersion == null) {
        return const AppUpdateResult(hasUpdate: false);
      }

      // Check if remote version is strictly newer by SemVer or higher build number
      final semVerCmp = AppVersion.compareSemVer(remoteVersion.version, AppVersion.currentVersion);
      final isNewerVersion = semVerCmp > 0;
      final isNewerBuild = semVerCmp == 0 && remoteVersion.buildNumber > AppVersion.currentBuildNumber;

      final hasUpdate = isNewerVersion || isNewerBuild;
      if (!hasUpdate) {
        return const AppUpdateResult(hasUpdate: false);
      }

      final isForced = remoteVersion.forceUpdate;

      // Check if user previously dismissed this version (unless forced or manual check)
      if (!isManual && !isForced) {
        final isSilenced = await _isDismissedRecently(remoteVersion.version);
        if (isSilenced) {
          debugPrint('ℹ️ Update ${remoteVersion.version} available, but dismissed recently');
          return const AppUpdateResult(hasUpdate: false);
        }
      }

      return AppUpdateResult(
        hasUpdate: true,
        versionInfo: remoteVersion,
        isForced: isForced,
      );
    } catch (e) {
      debugPrint('⚠️ Version check skipped: $e');
      return const AppUpdateResult(hasUpdate: false);
    }
  }

  /// Mark a version as dismissed by the user for cooldown duration
  Future<void> dismissUpdate(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDismissedVersion, version);
      await prefs.setInt(_keyDismissedTime, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Check if the user dismissed this update within cooldown window
  Future<bool> _isDismissedRecently(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedVersion = prefs.getString(_keyDismissedVersion);
      final dismissedTimeMs = prefs.getInt(_keyDismissedTime);

      if (dismissedVersion == version && dismissedTimeMs != null) {
        final dismissedTime = DateTime.fromMillisecondsSinceEpoch(dismissedTimeMs);
        final elapsed = DateTime.now().difference(dismissedTime);
        return elapsed < _dismissCooldown;
      }
    } catch (_) {}
    return false;
  }

  /// Trigger the update process with cache clearing
  Future<void> performUpdate(AppVersionModel versionInfo) async {
    if (kIsWeb) {
      try {
        // Purge CacheStorage on web
        if (html.window.caches != null) {
          final keys = await html.window.caches!.keys();
          for (final key in keys) {
            await html.window.caches!.delete(key);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Cache purge notice: $e');
      }

      try {
        html.window.location.reload();
      } catch (_) {
        html.window.location.href = versionInfo.updateUrl;
      }
    } else {
      // On mobile/desktop: launch URL
      final uri = Uri.parse(versionInfo.updateUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}
