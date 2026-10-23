import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/pages/timetable/timetable_grid.dart';
import 'package:xzitpocket/pages/timetable/timetable_settings_page.dart';
import 'package:xzitpocket/providers/config_provider.dart';
import 'package:xzitpocket/services/course_storage.dart';
import 'package:xzitpocket/services/preferences_storage.dart';
import 'package:xzitpocket/ui/app_components.dart';
import 'package:xzitpocket/ui/app_theme.dart';

void main() {
  late Directory directory;
  late CourseStorage courseStorage;
  late PreferencesStorage preferencesStorage;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('xzitpocket_settings_');
    courseStorage = CourseStorage();
    await courseStorage.init(path: directory.path);
    SharedPreferences.setMockInitialValues({});
    preferencesStorage = PreferencesStorage();
    await preferencesStorage.init();
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Widget buildHostApp() => ProviderScope(
    overrides: [
      courseStorageProvider.overrideWithValue(courseStorage),
      preferencesStorageProvider.overrideWithValue(preferencesStorage),
    ],
    child: FTheme(
      data: AppTheme.light,
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  appRoute(
                    name: AppRouteNames.timetableSettings,
                    builder: (_) => const TimetableSettingsPage(),
                  ),
                ),
                child: const Text('打开个性化设置'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('repeatedly entering and leaving settings keeps content drawn', (
    tester,
  ) async {
    await tester.pumpWidget(buildHostApp());
    expect(find.text('打开个性化设置'), findsOneWidget);

    for (var round = 0; round < 3; round++) {
      await tester.tap(find.text('打开个性化设置'));
      await tester.pumpAndSettle();
      expect(
        find.text('个性化设置'),
        findsOneWidget,
        reason: 'settings page should render on round $round',
      );

      // Leave without touching anything, exactly like the reported repro.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(
        find.text('打开个性化设置'),
        findsOneWidget,
        reason: 'host page must stay rendered after pop (round $round)',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('course preview stays collapsed until pulled down', (
    tester,
  ) async {
    await tester.pumpWidget(buildHostApp());
    await tester.tap(find.text('打开个性化设置'));
    await tester.pumpAndSettle();

    // 默认收起：不渲染预览网格。
    expect(find.byType(TimetableGrid), findsNothing);

    // 点击标题展开。
    await tester.tap(find.text('课程预览'));
    await tester.pumpAndSettle();
    expect(find.byType(TimetableGrid), findsOneWidget);

    // 再次点击收起。
    await tester.tap(find.text('课程预览'));
    await tester.pumpAndSettle();
    expect(find.byType(TimetableGrid), findsNothing);
  });
}
