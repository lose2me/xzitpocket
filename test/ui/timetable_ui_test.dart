import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xzitpocket/models/course.dart';
import 'package:xzitpocket/pages/timetable/course_form_page.dart';
import 'package:xzitpocket/pages/timetable/course_picker_sheet.dart';
import 'package:xzitpocket/pages/timetable/timetable_grid.dart';
import 'package:xzitpocket/ui/app_components.dart';
import 'package:xzitpocket/ui/app_theme.dart';

void main() {
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
          semesterStart: DateTime(2026, 8, 10),
          borderColor: AppTheme.light.colors.border,
        ),
      ),
    );

    final divider = tester.widget<FDivider>(find.byType(FDivider));
    final style = divider.style(AppTheme.light.dividerStyles.horizontal);
    expect(style.padding, EdgeInsets.zero);
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

  testWidgets('editing a course keeps the form visible above delete footer', (
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
          onDelete: () async {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('课程名称'), findsOneWidget);
    expect(find.text('教师'), findsOneWidget);
    expect(find.text('地点'), findsOneWidget);
    expect(find.text('校区'), findsOneWidget);
    expect(find.text('周次'), findsOneWidget);
    expect(find.text('删除课程'), findsOneWidget);
    expect(tester.getSize(find.byType(ListView)).height, greaterThan(300));
  });

  testWidgets(
    'course selection fields use Forui pickers and color requires hash',
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
      final colorField = tester.widget<AppTextFormField>(
        find.byKey(const ValueKey('course-color-field')),
      );
      expect(colorField.controller!.text, '#F8D2D7');
      final formatter = colorField.inputFormatters!.single;
      final accepted = formatter.formatEditUpdate(
        const TextEditingValue(text: '#F8D2D7'),
        const TextEditingValue(text: '#12abef'),
      );
      expect(accepted.text, '#12ABEF');
      final rejected = formatter.formatEditUpdate(
        accepted,
        const TextEditingValue(text: '123456'),
      );
      expect(rejected.text, '#12ABEF');
      final cleared = formatter.formatEditUpdate(
        accepted,
        const TextEditingValue(),
      );
      expect(cleared.text, '#');
      expect(cleared.selection, const TextSelection.collapsed(offset: 1));

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
