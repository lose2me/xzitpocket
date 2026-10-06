import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/models/course.dart';
import 'package:xzitpocket/pages/profile/config_backup_page.dart';
import 'package:xzitpocket/pages/timetable/timetable_grid.dart';
import 'package:xzitpocket/pages/timetable/timetable_page.dart';
import 'package:xzitpocket/providers/config_provider.dart';
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
        expect(find.text('备用课表'), findsOneWidget);
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
      final refreshButton = find.byWidgetPredicate(
        (widget) =>
            widget is AppIconButton && widget.icon == FLucideIcons.refreshCw,
      );
      expect(toggleButton, findsOneWidget);
      expect(
        tester.getCenter(toggleButton).dx,
        greaterThan(tester.getCenter(refreshButton).dx),
      );
      expect(find.byType(PageView), findsOneWidget);
      final header = tester.widget<WeekHeader>(find.byType(WeekHeader));
      header.onToggleSchedule!();
      header.onToggleSchedule!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(container.read(secondaryScheduleProvider).active, isTrue);
      expect(find.text('正在预览备用课表'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(WeekHeader),
          matching: find.textContaining(RegExp(r'^第\d+周$')),
        ),
        findsOneWidget,
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
      expect(find.text('正在预览备用课表'), findsNothing);
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
