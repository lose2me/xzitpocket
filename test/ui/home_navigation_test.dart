import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/app.dart';
import 'package:xzitpocket/models/app_settings.dart';
import 'package:xzitpocket/models/course.dart';
import 'package:xzitpocket/pages/profile/profile_page.dart';
import 'package:xzitpocket/pages/profile/profile_components.dart';
import 'package:xzitpocket/pages/timetable/timetable_grid.dart';
import 'package:xzitpocket/pages/timetable/timetable_page.dart';
import 'package:xzitpocket/pages/timetable/timetable_settings_page.dart';
import 'package:xzitpocket/pages/timetable/time_column.dart';
import 'package:xzitpocket/pages/tools/tools_page.dart';
import 'package:xzitpocket/providers/config_provider.dart';
import 'package:xzitpocket/providers/app_settings_provider.dart';
import 'package:xzitpocket/services/course_storage.dart';
import 'package:xzitpocket/services/preferences_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    measuredAdaptiveSectionHeight.value = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (_) async => <String, String>{
        'appName': '掌上徐工',
        'packageName': 'live.xuda.xzitpocket',
        'version': '2.2.0',
        'buildNumber': '2200',
        'buildSignature': '',
      },
    );
  });

  for (final (height, bottomInset, noonCourse) in [
    (844.0, 34.0, false),
    (844.0, 0.0, true),
    (480.0, 48.0, false),
    (1900.0, 24.0, true),
  ]) {
    testWidgets('9 visible rows fill the body ($height, $bottomInset, '
        'noon course $noonCourse)', (tester) async {
      await _pumpApp(
        tester,
        bottomInset: bottomInset,
        height: height,
        hasCourses: true,
        noonCourse: noonCourse,
        personalization: {'timetable_course_text_template': '{课程}'},
      );
      final (grid, viewport, column) = _timetableGeometry(tester);
      expect(column.cellHeight * 9, closeTo(viewport.height, 0.000001));
      expect(
        measuredAdaptiveSectionHeight.value,
        closeTo(column.cellHeight, 0.000001),
      );
      expect(column.hiddenSlots, noonCourse ? isEmpty : {5, 6});
      final row = find.descendant(
        of: grid,
        matching: find.byKey(const ValueKey('timetable-grid-cell-0-8')),
      );
      expect(tester.getBottomLeft(row).dy, closeTo(viewport.bottom, 0.000001));
      expect(tester.takeException(), isNull);
    });
  }

  for (final custom in [false, true]) {
    testWidgets('cold-start settings keep the default and preview exact '
        'while Home is covered (custom $custom)', (tester) async {
      await _pumpApp(
        tester,
        bottomInset: 34,
        loggedIn: false,
        hasCourses: true,
        personalization: {
          if (custom) 'timetable_section_height': 72.0,
          'timetable_course_text_template': '{课程}',
        },
      );
      expect(find.byType(TimetablePage), findsNothing);
      final homeContext = tester.element(find.byType(FBottomNavigationBar));
      Navigator.of(homeContext).push(
        MaterialPageRoute<void>(builder: (_) => const TimetableSettingsPage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('课表网格'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      var tile = _sectionHeightTile(tester);
      final originalDefault = tile.defaultValue;
      expect(tile.value, custom ? 72 : originalDefault);
      final context = tester.element(find.byType(TimetableSettingsPage));
      final container = ProviderScope.containerOf(context);
      await container
          .read(appSettingsProvider.notifier)
          .setTimetableDayHeaderHeight(80);
      await tester.pump();
      await tester.pump();
      // Finish the tab transition after the layout publishes its measurement.
      await tester.pump(const Duration(milliseconds: 300));
      tile = _sectionHeightTile(tester);
      expect(tile.defaultValue, closeTo(originalDefault - 40 / 9, 0.000001));
      expect(tile.value, custom ? 72 : tile.defaultValue);
      if (custom) {
        await container
            .read(appSettingsProvider.notifier)
            .resetTimetableSectionHeight();
        await tester.pump();
        expect(
          container
              .read(preferencesStorageProvider)
              .hasTimetableSectionHeight(),
          isFalse,
        );
        container.invalidate(appSettingsProvider);
        await tester.pump();
        expect(
          container.read(appSettingsProvider).timetableSectionHeightIsCustom,
          isFalse,
        );
        expect(
          container.read(appSettingsProvider).timetableDayHeaderHeight,
          80,
        );
      }
      tile = _sectionHeightTile(tester);
      await tester.tap(find.text('课程预览'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.widget<TimetableGrid>(find.byType(TimetableGrid)).sectionHeight,
        tile.defaultValue,
      );
      expect(measuredAdaptiveSectionHeight.value, tile.defaultValue);
      await tester.tap(find.text('课程预览'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      tester.view.physicalSize = const Size(390 * 2.75, 480 * 2.75);
      await tester.pump();
      await tester.pump();
      tile = _sectionHeightTile(tester);
      expect(tile.defaultValue, lessThan(40));
      expect(tile.value, tile.defaultValue);
      expect(tile.min, lessThanOrEqualTo(tile.value));
      Navigator.of(context).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _selectTab(tester, '课表');
      final (_, viewport, column) = _timetableGeometry(tester);
      expect(column.cellHeight, closeTo(tile.defaultValue, 0.000001));
      expect(column.cellHeight * 9, closeTo(viewport.height, 0.000001));
      expect(tester.takeException(), isNull);
    });
  }

  for (final brightness in Brightness.values) {
    for (final bottomInset in [0.0, 24.0, 34.0, 48.0]) {
      testWidgets('navigation geometry and system style stay equal across tabs '
          '(${brightness.name}, bottom inset $bottomInset)', (tester) async {
        await _pumpApp(
          tester,
          brightness: brightness,
          bottomInset: bottomInset,
        );
        final navigation = find.byType(FBottomNavigationBar);
        final rect = tester.getRect(navigation);
        final navigationContext = tester.element(navigation);
        final mediaQuery = MediaQuery.of(navigationContext);
        final shell = navigationContext
            .findAncestorWidgetOfExactType<FScaffold>()!;
        expect(
          shell
              .scaffoldStyle(navigationContext.theme.scaffoldStyle)
              .footerDecoration,
          const BoxDecoration(),
        );
        final decoration = _navigationDecoration(tester);
        final overlay = _bottomOverlay(tester);
        expect(overlay, isNotNull);

        for (final label in ['服务', '我的', '课表']) {
          await _selectTab(tester, label);
          expect(tester.getRect(navigation), rect, reason: label);
          expect(
            MediaQuery.of(tester.element(navigation)),
            mediaQuery,
            reason: label,
          );
          expect(_navigationDecoration(tester), decoration, reason: label);
          expect(_bottomOverlay(tester), overlay, reason: label);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'profile and services do not reserve the bottom safe area twice',
    (tester) async {
      await _pumpApp(tester, bottomInset: 34);
      final navigationTop = tester
          .getTopLeft(find.byType(FBottomNavigationBar))
          .dy;

      for (final (label, pageType) in [
        ('服务', ToolsPage),
        ('我的', ProfilePage),
      ]) {
        await _selectTab(tester, label);
        final list = find.descendant(
          of: find.byType(pageType),
          matching: find.byType(ListView),
        );
        expect(tester.getBottomLeft(list).dy, navigationTop, reason: label);
      }
    },
  );

  testWidgets('keyboard metrics leave the shell navigation height stable', (
    tester,
  ) async {
    await _pumpApp(tester, bottomInset: 34);
    await _selectTab(tester, '我的');
    final navigation = find.byType(FBottomNavigationBar);
    final rect = tester.getRect(navigation);

    for (final keyboardInset in [120.0, 300.0, 0.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset * 2.75);
      tester.view.padding = FakeViewPadding(
        top: 28 * 2.75,
        bottom: keyboardInset == 0 ? 34 * 2.75 : 0,
      );
      await tester.pump();
      expect(tester.getRect(navigation), rect);
      final profileQuery = MediaQuery.of(
        tester.element(find.byType(ProfilePage)),
      );
      expect(profileQuery.viewInsets.bottom, keyboardInset);
      expect(profileQuery.padding.bottom, 0);
    }
    await _selectTab(tester, '课表');
    expect(tester.getRect(navigation), rect);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a populated timetable keeps the same navigation as services and profile',
    (tester) async {
      await _pumpApp(tester, bottomInset: 24, hasCourses: true);
      expect(find.byType(TimetableGrid), findsWidgets);
      final navigation = find.byType(FBottomNavigationBar);
      final rect = tester.getRect(navigation);
      for (final label in ['服务', '我的', '课表']) {
        await _selectTab(tester, label);
        expect(tester.getRect(navigation), rect, reason: label);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact windows normalize system insets equally for all tabs', (
    tester,
  ) async {
    await _pumpApp(tester, bottomInset: 48, height: 480);
    final navigation = find.byType(FBottomNavigationBar);
    final rect = tester.getRect(navigation);
    expect(MediaQuery.viewPaddingOf(tester.element(navigation)).bottom, 24);
    for (final (label, pageType) in [
      ('服务', ToolsPage),
      ('我的', ProfilePage),
      ('课表', TimetablePage),
    ]) {
      await _selectTab(tester, label);
      expect(tester.getRect(navigation), rect, reason: label);
      expect(
        MediaQuery.paddingOf(tester.element(find.byType(pageType))).bottom,
        0,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the logged-out profile consumes the safe area above the footer',
    (tester) async {
      await _pumpApp(tester, bottomInset: 34, loggedIn: false);
      expect(find.byType(ProfilePage), findsOneWidget);
      final navigation = find.byType(FBottomNavigationBar);
      expect(
        tester.getSize(navigation).height,
        closeTo(61 + 34 * 2 / 3, 0.001),
      );
      expect(
        MediaQuery.paddingOf(tester.element(find.byType(ProfilePage))).bottom,
        0,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'navigation diagnostic logs contain the measured layout when enabled',
    (tester) async {
      final messages = <String>[];
      final originalDebugPrint = debugPrint;
      try {
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null && message.startsWith('[NAV_LAYOUT] ')) {
            messages.add(message);
          }
        };
        await _pumpApp(tester, bottomInset: 34);
        await _selectTab(tester, '服务');
        await _selectTab(tester, '我的');
      } finally {
        debugPrint = originalDebugPrint;
      }

      if (!const bool.fromEnvironment('NAV_LAYOUT_DIAGNOSTICS')) {
        expect(messages, isEmpty);
        return;
      }
      final records = messages
          .map(
            (message) =>
                jsonDecode(message.substring('[NAV_LAYOUT] '.length))
                    as Map<String, dynamic>,
          )
          .toList();
      expect(records.map((record) => record['tab']).toSet(), {
        '课表',
        '服务',
        '我的',
      });
      final record = records.last;
      final rect = tester.getRect(find.byType(FBottomNavigationBar));
      expect(record['rect'], [rect.left, rect.top, rect.width, rect.height]);
      expect(record['backgroundVisible'], false);
      expect(record['navigation']['viewPaddingBottom'], 34);
      expect(record['page']['paddingBottom'], 0);
      expect(record['shellSystemOverlay'], isA<Map<String, dynamic>>());
    },
  );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  required double bottomInset,
  bool hasCourses = false,
  bool loggedIn = true,
  double height = 844,
  bool noonCourse = false,
  Map<String, Object> personalization = const {},
}) async {
  const dpr = 2.75;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(390 * dpr, height * dpr);
  tester.view.viewPadding = FakeViewPadding(
    top: 28 * dpr,
    bottom: bottomInset * dpr,
  );
  tester.view.padding = FakeViewPadding(
    top: 28 * dpr,
    bottom: bottomInset * dpr,
  );
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  SharedPreferences.setMockInitialValues({
    'disclaimer_accepted': true,
    if (loggedIn) 'student_id': '123',
    ...personalization,
  });
  final storage = PreferencesStorage();
  await storage.init();
  final courses = _MemoryCourseStorage(
    hasCourses
        ? [
            Course(
              title: '高等数学',
              teacher: '张老师',
              weekday: 1,
              sessions: noonCourse ? const [5, 6] : const [1, 2],
              weeks: List.generate(30, (index) => index + 1),
              campus: '',
              place: '教室',
              colorIndex: 0,
            ),
          ]
        : const [],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        courseStorageProvider.overrideWithValue(courses),
        preferencesStorageProvider.overrideWithValue(storage),
      ],
      child: App(courseStorage: courses),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _selectTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(FBottomNavigationBar),
      matching: find.text(label),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

(Finder, Rect, TimeColumn) _timetableGeometry(WidgetTester tester) {
  final column = find.byType(TimeColumn).first;
  final grid = find.ancestor(of: column, matching: find.byType(TimetableGrid));
  final viewport = find.descendant(
    of: grid,
    matching: find.byType(SingleChildScrollView),
  );
  return (grid, tester.getRect(viewport), tester.widget<TimeColumn>(column));
}

ProfileSettingsSliderTile _sectionHeightTile(WidgetTester tester) => tester
    .widgetList<ProfileSettingsSliderTile>(
      find.byType(ProfileSettingsSliderTile),
    )
    .singleWhere((tile) => tile.title == '课节高度');

Decoration _navigationDecoration(WidgetTester tester) => tester
    .widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(FBottomNavigationBar),
            matching: find.byType(DecoratedBox),
          )
          .first,
    )
    .decoration;

SystemUiOverlayStyle? _bottomOverlay(WidgetTester tester) {
  final view = tester.view;
  final offset = Offset(
    view.physicalSize.width / 2,
    view.physicalSize.height - 1 - view.padding.bottom / 2,
  );
  return tester.binding.renderViews.single.debugLayer!
      .find<SystemUiOverlayStyle>(offset);
}

class _MemoryCourseStorage extends CourseStorage {
  final List<Course> courses;

  _MemoryCourseStorage(this.courses);

  @override
  List<Course> getCourses() => courses;

  @override
  List<Course> getOriginalCourses() => courses;

  @override
  (List<int>, List<Course>) getCoursesWithKeys() =>
      (List.generate(courses.length, (index) => index), courses);
}
