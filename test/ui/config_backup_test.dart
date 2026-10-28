import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/models/course.dart';
import 'package:xzitpocket/models/school_calendar.dart';
import 'package:xzitpocket/pages/profile/config_backup_page.dart';
import 'package:xzitpocket/pages/timetable/timetable_grid.dart';
import 'package:xzitpocket/pages/timetable/timetable_page.dart';
import 'package:xzitpocket/providers/config_provider.dart';
import 'package:xzitpocket/providers/app_settings_provider.dart';
import 'package:xzitpocket/providers/schedule_provider.dart';
import 'package:xzitpocket/services/widget_service.dart';
import 'package:xzitpocket/providers/secondary_schedule_provider.dart';
import 'package:xzitpocket/services/course_storage.dart';
import 'package:xzitpocket/services/preferences_storage.dart';
import 'package:xzitpocket/ui/app_components.dart';
import 'package:xzitpocket/ui/app_theme.dart';
import 'package:xzitpocket/widgets/week_header.dart';

void main() {
  late Directory directory;
  late CourseStorage storage;
  late PreferencesStorage preferences;
  late ProviderContainer container;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('xzitpocket_backup_ui_');
    storage = CourseStorage();
    await storage.init(path: directory.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    preferences = PreferencesStorage();
    await preferences.init();
    await storage.clearCourses();
    container = ProviderContainer(
      overrides: [
        courseStorageProvider.overrideWithValue(storage),
        preferencesStorageProvider.overrideWithValue(preferences),
      ],
    );
  });

  tearDown(() => container.dispose());

  for (final emptyInitialSchedule in [false, true]) {
    testWidgets(
      'backup page uses a single share-code page with emptyInitialSchedule=$emptyInitialSchedule',
      (tester) async {
        final initial = emptyInitialSchedule
            ? <Course>[]
            : [_course('Baseline')];
        await tester.runAsync(() async {
          await storage.saveCourses(initial);
          if (!emptyInitialSchedule) {
            await storage.clearCourseDayOccurrence(weekday: 1, week: 1);
          }
          await storage.addCourse(_course('Added', weekday: 3));
        });
        await tester.pumpWidget(_app(container, const ConfigBackupPage()));
        await tester.pump();
        expect(find.text('分享码'), findsOneWidget);
        expect(find.text('个性化设置'), findsOneWidget);
        expect(find.text('第二课表'), findsOneWidget);
        expect(find.text('个性化设置 JSON'), findsNothing);
        expect(find.text('当前课程 JSON'), findsNothing);
        expect(find.text('备用课程 JSON'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      semanticsEnabled: false,
    );
  }

  testWidgets(
    'calendar notice persists and cloud toggle only controls visibility',
    (tester) async {
      await preferences.setSchoolCalendarUpdateNotice(true);
      semesterCalendar.setCalendarUpdateNotice(true);
      addTearDown(() => semesterCalendar.setCalendarUpdateNotice(false));
      await tester.pumpWidget(_app(container, const TimetablePage()));
      await tester.pump();
      expect(find.text('云端课程有所调整，建议重建课表'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('云端课程有所调整，建议重建课表'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is AppIconButton && widget.icon == FLucideIcons.x,
        ),
        findsNothing,
      );

      await container
          .read(appSettingsProvider.notifier)
          .setUseCloudTimetableAdjustments(false);
      await tester.pump();
      expect(find.text('云端课程有所调整，建议重建课表'), findsNothing);
      expect(preferences.getSchoolCalendarUpdateNotice(), isTrue);
      await container
          .read(appSettingsProvider.notifier)
          .setUseCloudTimetableAdjustments(true);
      await tester.pump();
      expect(find.text('云端课程有所调整，建议重建课表'), findsOneWidget);
      await tester.runAsync(() async {
        try {
          await container.read(scheduleProvider.notifier).replaceCourses([
            _course('Backup'),
          ]);
        } on WidgetSyncException {
          /* Native widget bridge is absent in this test. */
        }
      });
      await tester.pump();
      expect(semesterCalendar.calendarUpdateNotice, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_app(container, const TimetablePage()));
      await tester.pump();
      expect(find.text('云端课程有所调整，建议重建课表'), findsOneWidget);

      await tester.runAsync(() async {
        try {
          await container
              .read(scheduleProvider.notifier)
              .updateFromLoginResult(
                courses: [_course('Fresh OA')],
                studentId: '20260001',
                studentName: '',
                collegeName: '',
                className: '',
              );
        } on WidgetSyncException {
          /* Timetable persistence still succeeded. */
        }
      });
      await tester.pump();
      expect(find.text('云端课程有所调整，建议重建课表'), findsNothing);
      expect(preferences.getSchoolCalendarUpdateNotice(), isFalse);
      expect(storage.getOriginalCourses().single.title, 'Fresh OA');
      await tester.pumpWidget(const SizedBox.shrink());
    },
    semanticsEnabled: false,
  );

  testWidgets(
    'OA refresh replaces a stale original snapshot even if visible courses match',
    (tester) async {
      await tester.runAsync(() async {
        await storage.saveCourses([_course('Old original')]);
        await storage.clearCourseDayOccurrence(weekday: 1, week: 1);
        await storage.addCourse(_course('Current OA'));
        final notifier = container.read(scheduleProvider.notifier);
        try {
          await notifier.updateFromLoginResult(
            courses: [_course('Current OA')],
            studentId: '20260001',
            studentName: '',
            collegeName: '',
            className: '',
          );
        } on WidgetSyncException {
          /* Native bridge is absent. */
        }
      });
      expect(storage.getOriginalCourses().single.title, 'Current OA');
    },
  );

  testWidgets('logout clears both persisted and visible calendar notices', (
    tester,
  ) async {
    await preferences.setSchoolCalendarUpdateNotice(true);
    await preferences.setResourceUploadStatsCache('{"student_id":"20260001"}');
    semesterCalendar.setCalendarUpdateNotice(true);
    addTearDown(() => semesterCalendar.setCalendarUpdateNotice(false));
    await tester.runAsync(
      () => container.read(configProvider.notifier).logout(),
    );
    expect(preferences.getSchoolCalendarUpdateNotice(), isFalse);
    expect(semesterCalendar.calendarUpdateNotice, isFalse);
    expect(container.read(configProvider).studentId, isNull);
    expect(preferences.getResourceUploadStatsCache(), isNull);
    expect(preferences.getResourceUploadStatsCacheTime(), isNull);
  });

  testWidgets(
    'schedule flipping keeps one viewport and the secondary timetable is read-only',
    (tester) async {
      final weeks = List.generate(104, (index) => index + 1);
      await tester.runAsync(() async {
        await storage.saveCourses([_course('Primary', weeks: weeks)]);
        await container.read(secondaryScheduleProvider.notifier).setCourses([
          _course('Secondary', weeks: weeks),
        ]);
      });
      await tester.pumpWidget(_app(container, const TimetablePage()));
      await tester.pump();
      final toggleButton = find.byWidgetPredicate(
        (widget) =>
            widget is AppIconButton &&
            widget.icon == FLucideIcons.arrowLeftRight,
      );
      expect(toggleButton, findsOneWidget);
      // The old sync button is gone; syncing is triggered by pull-to-refresh.
      expect(find.byIcon(FLucideIcons.refreshCw), findsNothing);
      expect(find.byType(PageView), findsOneWidget);
      final header = tester.widget<WeekHeader>(find.byType(WeekHeader));
      header.onToggleSchedule!();
      header.onToggleSchedule!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(container.read(secondaryScheduleProvider).active, isTrue);
      expect(find.text('正在预览第二课表'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(WeekHeader),
          matching: find.textContaining(RegExp(r'^第\d+周$')),
        ),
        findsNothing,
      );
      expect(find.byType(PageView), findsOneWidget);
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.positions,
        hasLength(1),
      );
      expect(
        find.byType(LongPressDraggable<TimetableDayDragData>),
        findsNothing,
      );
      for (final grid in tester.widgetList<TimetableGrid>(
        find.byType(TimetableGrid),
      )) {
        expect(grid.onCourseTap, isNull);
        expect(grid.onDayDrop, isNull);
        expect(grid.suppressDayDrop, isTrue);
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      tester.widget<WeekHeader>(find.byType(WeekHeader)).onToggleSchedule!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(container.read(secondaryScheduleProvider).active, isFalse);
      expect(find.text('正在预览第二课表'), findsNothing);
      expect(find.byType(PageView), findsOneWidget);
      expect(storage.getCourses().single.title, 'Primary');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    semanticsEnabled: false,
  );
}

Widget _app(ProviderContainer container, Widget child) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: FLocalizations.localizationsDelegates,
        supportedLocales: FLocalizations.supportedLocales,
        builder: (context, child) => FTheme(
          data: AppTheme.light,
          child: FTooltipGroup(child: child!),
        ),
        home: child,
      ),
    );

Course _course(
  String title, {
  int weekday = 1,
  List<int> weeks = const [1, 2],
}) => Course(
  title: title,
  teacher: 'Teacher',
  weekday: weekday,
  sessions: [1, 2],
  weeks: weeks,
  campus: '',
  place: '',
  colorIndex: 0,
);
