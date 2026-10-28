import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/models/resource_center.dart';
import 'package:xzitpocket/pages/tools/learning_center_page.dart';
import 'package:xzitpocket/services/learning_repository.dart';
import 'package:xzitpocket/services/preferences_storage.dart';
import 'package:xzitpocket/services/resource_center_cache.dart';
import 'package:xzitpocket/services/resource_download_service.dart';
import 'package:xzitpocket/ui/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'renaming keeps downloaded markers and replacing files clears them',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'resource_downloads_v1': jsonEncode({
          'res-1|pdf|original': {
            'uri': 'content://downloads/1',
            'name': 'paper.pdf',
          },
          'tbx-1|pdf|original': {
            'uri': 'content://downloads/2',
            'name': 'book.pdf',
          },
        }),
      });
      final preferences = PreferencesStorage();
      await preferences.init();
      const bridge = MethodChannel('live.xuda.xzitpocket/app_bridge');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(bridge, (call) async => true);
      addTearDown(() => messenger.setMockMethodCallHandler(bridge, null));
      final repository = LearningRepository(
        preferencesStorage: preferences,
        fetcher: () async => [],
      );
      addTearDown(repository.dispose);

      Future<void> openCourse(String revision, String fileVersion) async {
        await preferences.setResourceCourseCache(
          'C1',
          ResourceCourseSnapshot(
            version: revision,
            resources: [
              CourseResourceItem(
                id: 'res-1',
                name: '试卷 $revision',
                hasPdf: true,
                fileVersion: fileVersion,
              ),
            ],
            textbooks: [
              CourseTextbookItem(
                id: 'tbx-1',
                name: '教材 $revision',
                hasPdf: true,
                fileVersion: fileVersion,
              ),
            ],
          ).encode(),
        );
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: FLocalizations.localizationsDelegates,
            supportedLocales: FLocalizations.supportedLocales,
            builder: (context, child) => FTheme(
              data: AppTheme.light,
              child: FToaster(child: FTooltipGroup(child: child!)),
            ),
            home: LearningCenterPage(
              key: ValueKey(revision),
              repository: repository,
              course: ResourceCourse(
                code: 'C1',
                name: '高等数学',
                version: revision,
              ),
              preferencesStorage: preferences,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await openCourse('first', 'original');
      expect(find.text('已下载'), findsNWidgets(2));
      await openCourse('renamed', 'original');
      expect(find.text('已下载'), findsNWidgets(2));
      await openCourse('replaced', 'replacement');
      expect(find.text('已下载'), findsNothing);
      expect(find.text('未下载'), findsNWidgets(2));
      expect(
        await ResourceDownloadService.instance.recordFor(
          'res-1',
          fileVersion: 'original',
        ),
        isNotNull,
      );
      expect(
        await ResourceDownloadService.instance.recordFor(
          'tbx-1',
          fileVersion: 'original',
        ),
        isNotNull,
      );
    },
  );
}
