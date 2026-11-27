import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/app.dart';
import 'package:xzitpocket/models/app_settings.dart';
import 'package:xzitpocket/models/course.dart';
import 'package:xzitpocket/pages/timetable/timetable_grid.dart';
import 'package:xzitpocket/pages/timetable/time_column.dart';
import 'package:xzitpocket/providers/config_provider.dart';
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

  for (final height in [480.0, 844.0]) {
    testWidgets('login and reset fields clear the keyboard at height $height', (
      tester,
    ) async {
      await _pumpApp(tester, bottomInset: 34, height: height, loggedIn: false);
      final navigation = find.byType(FBottomNavigationBar);
      final navRect = tester.getRect(navigation);
      const keyboardHeight = 260.0;
      Future<void> showKeyboard(Finder field) async {
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pump();
        tester.view.viewInsets = const FakeViewPadding(
          bottom: keyboardHeight * 2.75,
        );
        tester.view.padding = const FakeViewPadding(top: 28 * 2.75);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          tester.getRect(field).bottom,
          lessThanOrEqualTo(height - keyboardHeight),
        );
        expect(tester.getRect(field).top, greaterThanOrEqualTo(28));
        expect(tester.getRect(navigation), navRect);
      }

      await showKeyboard(find.byType(EditableText).last);
      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.viewInsets = const FakeViewPadding();
      tester.view.padding = const FakeViewPadding(
        top: 28 * 2.75,
        bottom: 34 * 2.75,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('找回密码'));
      await tester.tap(find.text('找回密码'));
      await tester.pump();
      expect(find.text('验证码'), findsOneWidget);
      expect(find.text('输入手机收到的六位验证码'), findsNothing);
      await showKeyboard(find.byType(FOtpField));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
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

(Finder, Rect, TimeColumn) _timetableGeometry(WidgetTester tester) {
  final column = find.byType(TimeColumn).first;
  final grid = find.ancestor(of: column, matching: find.byType(TimetableGrid));
  final viewport = find.descendant(
    of: grid,
    matching: find.byType(SingleChildScrollView),
  );
  return (grid, tester.getRect(viewport), tester.widget<TimeColumn>(column));
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
