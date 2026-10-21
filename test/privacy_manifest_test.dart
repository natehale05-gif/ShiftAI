import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ai/util/geo.dart';

/// The privacy manifest is what App Store Connect checks the privacy label
/// against. It declared an email and user content only, while the app
/// also sends a name, a username, a rough location and photos.
void main() {
  final String app =
      File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
  final String pubspec = File('pubspec.yaml').readAsStringSync();

  test('every kind of data the app sends is declared, none as tracking', () {
    for (final String kind in <String>[
      'EmailAddress', // signing in
      'Name', // /v1/me, the boards
      'UserID', // the handle
      'OtherUserContent', // prompts, chats, notes, the vault
    ]) {
      expect(app, contains('NSPrivacyCollectedDataType$kind'), reason: kind);
    }
    // A dependency that collects means a declaration that says so.
    if (pubspec.contains('geolocator:')) {
      expect(app, contains('NSPrivacyCollectedDataTypeCoarseLocation'));
      expect(app, isNot(contains('NSPrivacyCollectedDataTypePreciseLocation')),
          reason: 'only a rounded fix leaves the device');
    }
    if (pubspec.contains('file_picker:')) {
      expect(app, contains('NSPrivacyCollectedDataTypePhotosorVideos'));
    }
    expect(app, contains('<key>NSPrivacyTracking</key>\n  <false/>'));
    expect(
        app,
        isNot(contains(
            '<key>NSPrivacyCollectedDataTypeTracking</key>\n      <true/>')));
  });

  test('UserDefaults has a reason for the app and for the App Group', () {
    expect(app, contains('<string>CA92.1</string>'));
    if (File('ios/Runner/Runner.entitlements')
        .readAsStringSync()
        .contains('group.club.shiftai.app')) {
      expect(app, contains('<string>1C8F.1</string>'),
          reason: 'home_widget writes into the App Group');
      final File widgets =
          File('ios/ShiftLeaderboardWidgets/PrivacyInfo.xcprivacy');
      expect(widgets.existsSync(), isTrue,
          reason: 'the widget extension is its own bundle');
      expect(widgets.readAsStringSync(), contains('<string>1C8F.1</string>'));
    }
  });

  test('a location fix is rounded to about a kilometre before it is sent', () {
    final GeoFix fix = GeoFix.coarse(30.267153, -97.743061);
    expect(fix.lat, 30.27);
    expect(fix.lng, -97.74);
  });
}
