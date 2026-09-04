import 'package:flutter/material.dart';
import '../core/config/app_version.dart';
import '../core/services/app_update_service.dart';
import '../data/models/app_version_model.dart';
import '../widgets/update_notification_dialog.dart';

/// Provider for managing update state and triggering non-blocking checks
class AppUpdateProvider extends ChangeNotifier {
  final AppUpdateService _service = AppUpdateService.instance;

  bool _isChecking = false;
  bool _hasUpdate = false;
  bool _isDialogShowing = false;
  AppVersionModel? _latestVersion;
  String? _error;
  DateTime? _lastChecked;

  // ─── Getters ───
  bool get isChecking => _isChecking;
  bool get hasUpdate => _hasUpdate;
  bool get isDialogShowing => _isDialogShowing;
  AppVersionModel? get latestVersion => _latestVersion;
  String? get error => _error;
  DateTime? get lastChecked => _lastChecked;
  String get currentVersion => AppVersion.currentVersion;
  bool get isForceUpdate => _latestVersion?.forceUpdate ?? false;

  /// Check for application updates (non-blocking)
  Future<void> checkForUpdate({
    bool isManual = false,
    BuildContext? context,
  }) async {
    if (_isChecking) return;

    _isChecking = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.checkForUpdate(isManual: isManual);
      _hasUpdate = result.hasUpdate;
      _latestVersion = result.versionInfo;
      _lastChecked = DateTime.now();

      debugPrint('🚀 AppUpdateProvider: checked -> hasUpdate=$_hasUpdate, '
          'latest=${_latestVersion?.version}, current=$currentVersion');

      if (_hasUpdate && _latestVersion != null && context != null && context.mounted && !_isDialogShowing) {
        _showUpdateDialog(context, _latestVersion!);
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('⚠️ AppUpdateProvider error: $e');
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Display the enterprise update dialog safely
  void _showUpdateDialog(BuildContext context, AppVersionModel versionInfo) {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: !versionInfo.forceUpdate,
      builder: (ctx) => UpdateNotificationDialog(
        versionInfo: versionInfo,
        onUpdate: () async {
          _isDialogShowing = false;
          await _service.performUpdate(versionInfo);
        },
        onDismiss: () async {
          _isDialogShowing = false;
          Navigator.of(ctx).pop();
          await _service.dismissUpdate(versionInfo.version);
          _hasUpdate = false;
          notifyListeners();
        },
      ),
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  /// Manually trigger update
  Future<void> performUpdate() async {
    if (_latestVersion != null) {
      await _service.performUpdate(_latestVersion!);
    }
  }

  /// Dismiss notification
  Future<void> dismiss() async {
    if (_latestVersion != null) {
      await _service.dismissUpdate(_latestVersion!.version);
      _hasUpdate = false;
      notifyListeners();
    }
  }
}
