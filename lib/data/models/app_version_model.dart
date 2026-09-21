import 'dart:convert';

/// Represents metadata about the latest release of Billova Retail.
class AppVersionModel {
  final String version;
  final int buildNumber;
  final String releaseDate;
  final List<String> releaseNotes;
  final bool forceUpdate;
  final String? minimumSupportedVersion;
  final String updateUrl;

  const AppVersionModel({
    required this.version,
    this.buildNumber = 1,
    required this.releaseDate,
    required this.releaseNotes,
    this.forceUpdate = false,
    this.minimumSupportedVersion,
    this.updateUrl = 'https://billova-retail.vercel.app',
  });

  factory AppVersionModel.fromJson(Map<String, dynamic> json) {
    var rawNotes = json['release_notes'];
    List<String> notes = [];
    if (rawNotes is List) {
      notes = rawNotes.map((e) => e.toString()).toList();
    } else if (rawNotes is String) {
      try {
        final decoded = jsonDecode(rawNotes);
        if (decoded is List) {
          notes = decoded.map((e) => e.toString()).toList();
        } else {
          notes = [rawNotes];
        }
      } catch (_) {
        notes = rawNotes.split('\n').where((s) => s.trim().isNotEmpty).toList();
      }
    }

    return AppVersionModel(
      version: json['version']?.toString() ?? '1.0.0',
      buildNumber: (json['build_number'] as num?)?.toInt() ?? 1,
      releaseDate: json['release_date']?.toString() ?? '',
      releaseNotes: notes,
      forceUpdate: json['force_update'] == true || json['force_update'] == 1,
      minimumSupportedVersion: json['minimum_supported_version']?.toString(),
      updateUrl: json['update_url']?.toString() ?? 'https://billova-retail.vercel.app',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'build_number': buildNumber,
      'release_date': releaseDate,
      'release_notes': releaseNotes,
      'force_update': forceUpdate,
      'minimum_supported_version': minimumSupportedVersion,
      'update_url': updateUrl,
    };
  }

  @override
  String toString() => 'AppVersionModel(version: $version, force: $forceUpdate, date: $releaseDate)';
}
