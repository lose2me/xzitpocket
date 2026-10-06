import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xzitpocket/models/course.dart';
import 'package:xzitpocket/models/school_calendar.dart';
import 'package:xzitpocket/pages/timetable/course_form_page.dart';
import 'package:xzitpocket/pages/timetable/course_picker_sheet.dart';
import 'package:xzitpocket/pages/timetable/course_card.dart';
import 'package:xzitpocket/pages/timetable/timetable_grid.dart';
import 'package:xzitpocket/pages/timetable/time_column.dart';
import 'package:xzitpocket/ui/app_components.dart';
import 'package:xzitpocket/ui/app_theme.dart';

void main() {
  testWidgets('course text vertical centering affects the card layout', (
    tester,
  ) async {
    final course = Course(
      title: '垂直居中测试',
      teacher: '',
      weekday: 1,
      sessions: const [1],
      weeks: const [1],
      campus: '',
      place: '',
      colorIndex: 0,
    );
    await tester.pumpWidget(
      _testApp(
        SizedBox(
          width: 140,
          height: 120,
          child: CourseCard(
            course: course,
            borderColor: Colors.black,
            centerVertical: true,
            hideLocation: true,
            hideTeacher: true,
          ),
        ),
      ),
    );

    final cardRect = tester.getRect(find.byType(CourseCard));
    final titleRect = tester.getRect(find.text('垂直居中测试'));
    expect(titleRect.center.dy, closeTo(cardRect.center.dy, 5));
  });

  testWidgets('course teacher brackets follow the appearance setting', (
    tester,
  ) async {
    final course = Course(
      title: '高等数学',
      teacher: '张老师',
      weekday: 1,
      sessions: const [1, 2],
      weeks: const [1],
      campus: '',
      place: '',
      colorIndex: 0,
    );

    Future<void> pumpCard({required bool hideBrackets}) => tester.pumpWidget(
      _testApp(
        SizedBox(
          width: 140,
          height: 120,
          child: CourseCard(
            course: course,
            borderColor: Colors.black,
            hideTeacher: false,
            hideTeacherBrackets: hideBrackets,
          ),
        ),
      ),
    );

    await pumpCard(hideBrackets: false);
    expect(find.text('【张老师】'), findsOneWidget);
    expect(find.text('张老师'), findsNothing);

    await pumpCard(hideBrackets: true);
    expect(find.text('【张老师】'), findsNothing);
    expect(find.text('张老师'), findsOneWidget);
  });

  testWidgets('course start time omits the session number and leading zero', (
    tester,
  ) async {
    final course = Course(
      title: '早课',
      teacher: '',
      weekday: 1,
      sessions: const [1],
      weeks: const [1],
      campus: '',
      place: '',
      colorIndex: 0,
    );

    await tester.pumpWidget(
      _testApp(
        SizedBox(
          width: 140,
          height: 120,
          child: CourseCard(
            course: course,
            borderColor: Colors.black,
            showStartTime: true,
          ),
        ),
      ),
    );

    expect(find.text('8:00'), findsOneWidget);
    expect(find.text('1 08:00'), findsNothing);
  });

  testWidgets('course title blank line increases detail spacing', (
    tester,
  ) async {
    final course = Course(
      title: '课程名称',
      teacher: '',
      weekday: 1,
      sessions: const [1, 2],
      weeks: const [1],
      campus: '',
      place: '教室',
      colorIndex: 0,
    );

    Future<double> placeTop({required bool addBlankLine}) async {
      await tester.pumpWidget(
        _testApp(
          SizedBox(
            width: 140,
            height: 120,
            child: CourseCard(
              course: course,
              borderColor: Colors.black,
              addBlankLineAfterTitle: addBlankLine,
            ),
          ),
        ),
      );
      return tester.getTopLeft(find.text('@教室')).dy;
    }

    final normalTop = await placeTop(addBlankLine: false);
    final blankLineTop = await placeTop(addBlankLine: true);

    expect(blankLineTop, greaterThan(normalTop + 8));
  });

  testWidgets('horizontal centering applies to every course text line', (
    tester,
  ) async {
    final course = Course(
      title: '课程名称很长需要换行',
      teacher: '张老师',
      weekday: 1,
      sessions: const [1, 2],
      weeks: const [1],
      campus: '中心校区',
      place: '教室101',
      colorIndex: 0,
    );

    await tester.pumpWidget(
      _testApp(
        SizedBox(
          width: 100,
          height: 160,
          child: CourseCard(
            course: course,
            borderColor: Colors.black,
            centerHorizontal: true,
            showStartTime: true,
            hideTeacher: false,
          ),
        ),
      ),
    );

    for (final label in ['课程名称很长需要换行', '8:00', '@教室101', '中心校区', '张老师']) {
      expect(tester.widget<Text>(find.text(label)).textAlign, TextAlign.center);
    }
  });

  testWidgets('course border modes preserve the same content width', (
    tester,
  ) async {
    final course = Course(
      title: '一行课程文字宽度测试',
      teacher: '',
      weekday: 1,
      sessions: const [1, 2],
      weeks: const [1],
      campus: '',
      place: '',
      colorIndex: 0,
    );

    Future<Size> contentSize(String borderType) async {
      await tester.pumpWidget(
        _testApp(
          SizedBox(
            width: 100,
            height: 100,
            child: CourseCard(
              course: course,
              borderColor: Colors.black,
              borderWidth: 3,
              borderType: borderType,
            ),
          ),
        ),
      );
      return tester.getSize(find.byType(ClipRRect));
    }

    final none = await contentSize('none');
    final solid = await contentSize('solid');
    final dashed = await contentSize('dashed');
    expect(solid, none);
    expect(dashed, none);
  });

  testWidgets('timetable date divider has no surrounding vertical gap', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _testApp(
        TimetableGrid(
          courses: const [],
          week: 1,
          calendar: semesterCalendar,
          borderColor: AppTheme.light.colors.border,
        ),
      ),
    );

    final divider = tester.widget<FDivider>(find.byType(FDivider));
    final style = divider.style(AppTheme.light.dividerStyles.horizontal);
    expect(style.padding, EdgeInsets.zero);
  });

  testWidgets('preview mode disables long-press day dragging', (tester) async {
    final course = Course(
      title: '预览课程',
      teacher: '',
      weekday: 1,
      sessions: const [1, 2],
      weeks: const [1],
      campus: '',
      place: '',
      colorIndex: 0,
    );

    await tester.pumpWidget(
      _testApp(
        SizedBox(
          width: 390,
          height: 260,
          child: TimetableGrid(
            courses: [course],
            week: 1,
            calendar: semesterCalendar,
            borderColor: AppTheme.light.colors.border,
            suppressDayDrop: true,
          ),
        ),
      ),
    );

    expect(find.byType(LongPressDraggable<TimetableDayDragData>), findsNothing);
  });

  testWidgets('current date override highlights the selected preview day', (
    tester,
  ) async {
    final friday = semesterCalendar.weekDates(1)[4];
    await tester.pumpWidget(
      _testApp(
        SizedBox(
          width: 390,
          height: 260,
          child: TimetableGrid(
            courses: const [],
            week: 1,
            calendar: semesterCalendar,
            currentDate: friday,
            borderColor: AppTheme.light.colors.border,
          ),
        ),
      ),
    );

    final fridayLabel = tester.widget<Text>(find.text('五'));
    expect(fridayLabel.style?.color, AppTheme.light.colors.primary);
    expect(
      find.byKey(const ValueKey('timetable-today-indicator-5')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('timetable-today-indicator-1')),
      findsNothing,
    );
  });

  testWidgets('day color markers gate the holiday date text color', (
    tester,
  ) async {
    final holidayCalendar = SemesterCalendar([
      SchoolDay(date: DateTime(2026, 8, 31), adjustment: '/'),
    ]);
    const pageTextColor = Color(0xFF123456);
    // Holiday foreground used by both the light theme and the grid fallback.
    const holidayTextColor = Color(0xFF176B38);

    Future<Color?> renderedLabelColor({
      required bool showColorMarkers,
      Color? pageTextColor,
      DateTime? currentDate,
    }) async {
      await tester.pumpWidget(
        _testApp(
          SizedBox(
            width: 390,
            height: 260,
            child: TimetableGrid(
              courses: const [],
              week: 1,
              calendar: holidayCalendar,
              borderColor: AppTheme.light.colors.border,
              currentDate: currentDate,
              pageTextColor: pageTextColor,
              showDayColorMarkers: showColorMarkers,
            ),
          ),
        ),
      );
      return tester.widget<Text>(find.text('一')).style?.color;
    }

    // Color markers on and no page text override: holiday foreground applies.
    expect(
      (await renderedLabelColor(showColorMarkers: true))?.toARGB32(),
      holidayTextColor.toARGB32(),
    );

    // A custom page text color is authoritative over holiday markup.
    expect(
      (await renderedLabelColor(
        showColorMarkers: true,
        pageTextColor: pageTextColor,
      ))?.toARGB32(),
      pageTextColor.toARGB32(),
    );

    // Markers off: no holiday color, follows the page text color.
    expect(
      (await renderedLabelColor(
        showColorMarkers: false,
        pageTextColor: pageTextColor,
      ))?.toARGB32(),
      pageTextColor.toARGB32(),
    );
    expect(
      (await renderedLabelColor(showColorMarkers: false))?.toARGB32(),
      AppTheme.light.colors.mutedForeground.toARGB32(),
    );

    // Today keeps the theme primary even when it is a holiday whose color
    // marker is enabled.
    expect(
      (await renderedLabelColor(
        showColorMarkers: true,
        currentDate: DateTime(2026, 8, 31),
      ))?.toARGB32(),
      AppTheme.light.colors.primary.toARGB32(),
    );
  });

  testWidgets('today side lines replace grid lines on shared boundaries', (
    tester,
  ) async {
    final tuesday = semesterCalendar.weekDates(1)[1];
    const gridColor = Color(0xFF112233);
    const todayColor = Color(0xFF445566);
    await tester.pumpWidget(
      _testApp(
        SizedBox(
          width: 390,
          height: 260,
          child: TimetableGrid(
            courses: const [],
            week: 1,
            calendar: semesterCalendar,
            currentDate: tuesday,
            borderColor: AppTheme.light.colors.border,
            gridLineColor: gridColor,
            gridOpacity: 1,
            gridLineWidth: 1,
            showTodayGridLines: true,
            todayLineColor: todayColor,
            todayLineOpacity: 1,
            todayLineWidth: 2,
          ),
        ),
      ),
    );

    Border borderFor(int dayIndex) {
      final cell = tester.widget<Container>(
        find.byKey(ValueKey('timetable-grid-cell-$dayIndex-0')),
      );
      return (cell.decoration! as BoxDecoration).border! as Border;
    }

    expect(borderFor(0).right, BorderSide.none);
    expect(borderFor(1).left, const BorderSide(color: todayColor, width: 2));
    expect(borderFor(1).right, const BorderSide(color: todayColor, width: 2));
    expect(borderFor(2).right, const BorderSide(color: gridColor, width: 1));
  });

  testWidgets('hiding dates preserves the configured day header height', (
    tester,
  ) async {
    Future<double> timeColumnTop({required bool hideDate}) async {
      await tester.pumpWidget(
        _testApp(
          SizedBox(
            width: 390,
            height: 500,
            child: TimetableGrid(
              courses: const [],
              week: 1,
              calendar: semesterCalendar,
              borderColor: AppTheme.light.colors.border,
              dayHeaderHeight: 64,
              hideDateUnderDay: hideDate,
            ),
          ),
        ),
      );
      return tester.getTopLeft(find.byType(TimeColumn)).dy;
    }

    final withDates = await timeColumnTop(hideDate: false);
    final withoutDates = await timeColumnTop(hideDate: true);

    expect(withoutDates, withDates);
  });

  testWidgets('app sheets render an opaque full-width surface', (tester) async {
    await tester.pumpWidget(
      _testApp(
        FScaffold(
          child: Builder(
            builder: (context) => Center(
              child: FButton(
                onPress: () => showAppSheet<void>(
                  context: context,
                  builder: (_) => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('课程详情'),
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byType(AppSheetSurface), findsOneWidget);
    final decorated = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(AppSheetSurface),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(
      (decorated.decoration as BoxDecoration).color,
      AppTheme.light.colors.card,
    );
    expect(
      tester.getSize(find.byType(AppSheetSurface)).width,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
    );
  });

  testWidgets('editing a course keeps the form visible above its footer', (
    tester,
  ) async {
    final course = Course(
      title: '高等数学',
      teacher: '张老师',
      weekday: 1,
      sessions: const [1, 2],
      weeks: const [1, 2, 3],
      campus: '中心校区',
      place: '教学楼101',
      colorIndex: 0,
      courseId: 'course-1',
    );

    await tester.pumpWidget(
      _testApp(
        CourseFormPage(
          weekday: course.weekday,
          session: course.startSession,
          existingCourse: course,
          onSave: (_) async {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('课程名称'), findsOneWidget);
    expect(find.text('教师'), findsOneWidget);
    expect(find.text('地点'), findsOneWidget);
    expect(find.text('校区'), findsOneWidget);
    expect(find.text('周次'), findsOneWidget);
    expect(find.byIcon(FLucideIcons.trash2), findsNothing);
    expect(tester.getSize(find.byType(ListView)).height, greaterThan(300));
  });

  testWidgets(
    'course selection fields use Forui pickers and color uses the profile control',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final course = Course(
        title: '高等数学',
        teacher: '张老师',
        weekday: 1,
        sessions: const [1, 2],
        weeks: const [1, 3, 5],
        campus: '中心校区',
        place: '教学楼101',
        colorIndex: 0,
      );

      await tester.pumpWidget(
        _testApp(
          CourseFormPage(
            weekday: course.weekday,
            session: course.startSession,
            existingCourse: course,
            onSave: (_) async {},
          ),
        ),
      );
      await tester.pump();

      for (final key in const [
        'course-weeks-field',
        'course-weekday-field',
        'course-session-field',
      ]) {
        expect(
          tester.widget<AppTextField>(find.byKey(ValueKey(key))).readOnly,
          isTrue,
        );
      }
      expect(
        tester
            .widget<AppTextField>(
              find.byKey(const ValueKey('course-session-field')),
            )
            .controller!
            .text,
        '第1-2节',
      );
      expect(find.text('颜色'), findsOneWidget);
      expect(find.text('自动分配'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('course-weekday-field')));
      await tester.pumpAndSettle();
      expect(find.byType(CourseWheelPickerSheet), findsOneWidget);
      expect(
        tester
            .widget<FPicker>(find.byType(FPicker))
            .children
            .whereType<FPickerWheel>(),
        hasLength(1),
      );
    },
  );

  testWidgets('session picker uses start and end wheels', (tester) async {
    await tester.pumpWidget(
      _testApp(
        CourseWheelPickerSheet(
          title: '选择节次',
          columns: [
            CoursePickerColumn(label: '开始节次', options: ['第1节', '第2节']),
            CoursePickerColumn(label: '结束节次', options: ['第1节', '第2节']),
          ],
          initialIndexes: [0, 1],
        ),
      ),
    );

    expect(
      tester
          .widget<FPicker>(find.byType(FPicker))
          .children
          .whereType<FPickerWheel>(),
      hasLength(2),
    );
  });

  testWidgets('week picker supports range pattern and custom weeks', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const CourseWeekPickerSheet(initialWeeks: [1, 4, 7], maxWeek: 20),
      ),
    );

    expect(
      tester
          .widget<FPicker>(find.byType(FPicker))
          .children
          .whereType<FPickerWheel>(),
      hasLength(3),
    );
    expect(find.byType(GridView), findsOneWidget);
  });
}

Widget _testApp(Widget home) => MaterialApp(
  localizationsDelegates: FLocalizations.localizationsDelegates,
  supportedLocales: FLocalizations.supportedLocales,
  builder: (context, child) => FTheme(data: AppTheme.light, child: child!),
  home: home,
);
