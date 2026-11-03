import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const manifestPath = 'android/app/src/main/AndroidManifest.xml';
  const rulesPath = 'android/app/src/main/res/xml/data_extraction_rules.xml';
  const domains = ['root', 'file', 'database', 'sharedpref', 'external'];

  test('manifest turns off Android backup of the app data', () {
    final manifest = File(manifestPath).readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
  });

  test('debug and profile overlays do not re-enable backup', () {
    for (final flavor in ['debug', 'profile']) {
      final overlay =
          File('android/app/src/$flavor/AndroidManifest.xml').readAsStringSync();
      expect(overlay, isNot(contains('android:allowBackup="true"')));
    }
  });

  test('data extraction rules exclude every domain from both transfers', () {
    final rules = File(rulesPath).readAsStringSync();
    for (final section in ['cloud-backup', 'device-transfer']) {
      final match = RegExp('<$section>([\\s\\S]*?)</$section>').firstMatch(rules);
      expect(match, isNotNull, reason: 'missing <$section>');
      for (final domain in domains) {
        expect(
          match!.group(1),
          contains('<exclude domain="$domain" path="."/>'),
          reason: '$section must exclude $domain',
        );
      }
    }
  });
}
