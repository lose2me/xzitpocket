import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/models/update_info.dart';

void main() {
  group('UpdateInfo', () {
    test('isForced returns true for upgradeType 3', () {
      const info = UpdateInfo(
        versionName: '2.1.0',
        versionCode: 2100,
        downloadUrl: 'https://example.com/app.apk',
        releaseNotes: 'Bug fixes',
        upgradeType: 3,
      );
      expect(info.isForced, true);
    });

    test('isForced returns false for upgradeType 1', () {
      const info = UpdateInfo(
        versionName: '2.1.0',
        versionCode: 2100,
        downloadUrl: 'https://example.com/app.apk',
        releaseNotes: '',
        upgradeType: 1,
      );
      expect(info.isForced, false);
    });

    test('isForced returns false for upgradeType 2', () {
      const info = UpdateInfo(
        versionName: '2.1.0',
        versionCode: 2100,
        downloadUrl: 'https://example.com/app.apk',
        releaseNotes: '',
        upgradeType: 2,
      );
      expect(info.isForced, false);
    });

    test('upgradeLabel returns correct labels', () {
      expect(
        const UpdateInfo(
          versionName: '',
          versionCode: 0,
          downloadUrl: '',
          releaseNotes: '',
          upgradeType: 1,
        ).upgradeLabel,
        '推荐更新',
      );

      expect(
        const UpdateInfo(
          versionName: '',
          versionCode: 0,
          downloadUrl: '',
          releaseNotes: '',
          upgradeType: 2,
        ).upgradeLabel,
        '推荐更新',
      );

      expect(
        const UpdateInfo(
          versionName: '',
          versionCode: 0,
          downloadUrl: '',
          releaseNotes: '',
          upgradeType: 3,
        ).upgradeLabel,
        '强制更新',
      );
    });

    test('upgradeLabel returns default for unknown type', () {
      const info = UpdateInfo(
        versionName: '',
        versionCode: 0,
        downloadUrl: '',
        releaseNotes: '',
        upgradeType: 99,
      );
      expect(info.upgradeLabel, '发现新版本');
    });
  });
}
