import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xzitpocket/models/course.dart';
import 'package:xzitpocket/models/school_calendar.dart';
import 'package:xzitpocket/pages/timetable/course_form_page.dart';
import 'package:xzitpocket/pages/timetable/course_picker_sheet.dart';
import 'package:xzitpocket/pages/timetable/timetable_grid.dart';
import 'package:xzitpocket/ui/app_theme.dart';

void main() {
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
