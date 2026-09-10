/// Centralized version configuration for SKYWALK Billing.
class AppVersion {
  AppVersion._();

  /// Current compiled application version
  static const String currentVersion = '1.0.2';

  /// Current internal build number
  static const int currentBuildNumber = 3;

  /// App name
  static const String appName = 'SKYWALK Billing';

  /// Default production URL
  static const String productionUrl = 'https://sky-walk-six.vercel.app';

  /// Compare two semantic version strings (e.g., "1.0.2" vs "1.0.0").
  /// Returns:
  /// - `1` if [latest] is newer than [current]
  /// - `-1` if [latest] is older than [current]
  /// - `0` if [latest] is equal to [current]
  static int compareSemVer(String latest, String current) {
    // Clean strings (remove 'v' prefix, whitespace)
    final cleanLatest = latest.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final cleanCurrent = current.trim().replaceFirst(RegExp(r'^[vV]'), '');

    final latestParts = cleanLatest.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final currentParts = cleanCurrent.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    // Pad to 3 parts (major, minor, patch)
    while (latestParts.length < 3) {
      latestParts.add(0);
    }
    while (currentParts.length < 3) {
      currentParts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return 1;
      if (latestParts[i] < currentParts[i]) return -1;
    }

    return 0;
  }

  /// Returns true if [latestVersion] is strictly newer than [currentVersion]
  static bool isNewerVersion(String latestVersion, [String current = currentVersion]) {
    return compareSemVer(latestVersion, current) > 0;
  }
}
