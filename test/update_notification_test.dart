import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:billova_retail/core/config/app_version.dart';
import 'package:billova_retail/data/models/app_version_model.dart';
import 'package:billova_retail/widgets/update_notification_dialog.dart';

void main() {
  group('AppVersion & SemVer Comparison Tests', () {
    test('compareSemVer correctly identifies newer versions', () {
      expect(AppVersion.compareSemVer('1.0.1', '1.0.0'), 1);
      expect(AppVersion.compareSemVer('1.1.0', '1.0.9'), 1);
      expect(AppVersion.compareSemVer('2.0.0', '1.9.9'), 1);
      expect(AppVersion.compareSemVer('v1.0.2', '1.0.1'), 1);
      expect(AppVersion.compareSemVer('1.0.0', '1.0.0'), 0);
      expect(AppVersion.compareSemVer('1.0.0', '1.0.1'), -1);
      expect(AppVersion.compareSemVer('0.9.0', '1.0.0'), -1);
    });

    test('isNewerVersion helper works against current version', () {
      expect(AppVersion.isNewerVersion('1.0.1', '1.0.0'), true);
      expect(AppVersion.isNewerVersion('1.0.0', '1.0.0'), false);
      expect(AppVersion.isNewerVersion('0.9.9', '1.0.0'), false);
    });
  });

  group('AppVersionModel Serialization Tests', () {
    test('parses from JSON correctly', () {
      final json = {
        'version': '1.0.2',
        'build_number': 3,
        'release_date': '14 Aug 2026',
        'release_notes': [
          '⚡ Fast Dashboard',
          '📊 Analytics Improvement',
        ],
        'force_update': false,
        'minimum_supported_version': '1.0.0',
        'update_url': 'https://sky-walk-six.vercel.app',
      };

      final model = AppVersionModel.fromJson(json);
      expect(model.version, '1.0.2');
      expect(model.buildNumber, 3);
      expect(model.releaseDate, '14 Aug 2026');
      expect(model.releaseNotes.length, 2);
      expect(model.forceUpdate, false);
      expect(model.updateUrl, 'https://sky-walk-six.vercel.app');
    });

    test('handles string release_notes fallback', () {
      final json = {
        'version': '1.0.3',
        'release_date': '15 Aug 2026',
        'release_notes': 'Feature 1\nFeature 2',
        'force_update': true,
      };

      final model = AppVersionModel.fromJson(json);
      expect(model.version, '1.0.3');
      expect(model.forceUpdate, true);
      expect(model.releaseNotes, ['Feature 1', 'Feature 2']);
    });
  });

  group('UpdateNotificationDialog UI Tests', () {
    testWidgets('renders dialog with release notes and action buttons', (tester) async {
      const versionInfo = AppVersionModel(
        version: '1.0.3',
        releaseDate: '10 Sep 2026',
        releaseNotes: [
          '⚡ Dashboard improvements',
          '📊 Performance boost',
        ],
        forceUpdate: false,
      );

      bool updateClicked = false;
      bool dismissClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateNotificationDialog(
              versionInfo: versionInfo,
              onUpdate: () => updateClicked = true,
              onDismiss: () => dismissClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('New Update Available'), findsOneWidget);
      expect(find.text('v${AppVersion.currentVersion}'), findsOneWidget);
      expect(find.text('v1.0.3'), findsOneWidget);
      expect(find.text('10 Sep 2026'), findsOneWidget);
      expect(find.text("What's New"), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);

      await tester.tap(find.text('Update Now'));
      expect(updateClicked, true);

      await tester.tap(find.text('Later'));
      expect(dismissClicked, true);
    });

    testWidgets('hides Later button when forceUpdate is true', (tester) async {
      const versionInfo = AppVersionModel(
        version: '2.0.0',
        releaseDate: '14 Aug 2026',
        releaseNotes: ['Mandatory security patch'],
        forceUpdate: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateNotificationDialog(
              versionInfo: versionInfo,
              onUpdate: () {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      expect(find.text('Update Now'), findsOneWidget);
      expect(find.text('Later'), findsNothing);
      expect(find.textContaining('This is a required update'), findsOneWidget);
    });
  });
}
