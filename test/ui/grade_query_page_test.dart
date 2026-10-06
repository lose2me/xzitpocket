import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/pages/tools/grade_query_page.dart';
import 'package:xzitpocket/services/auth_service.dart';
import 'package:xzitpocket/services/preferences_storage.dart';
import 'package:xzitpocket/ui/app_theme.dart';

void main() {
  testWidgets('academic course leaf opens a sheet instead of an inline table', (
    tester,
  ) async {
    final academic = AcademicStatus(
      gpa: 2.4,
      totalRequired: 160,
      totalEarned: 48.5,
      categories: const [
        AcademicCategory(
          name: '通识教育平台',
          reqCredits: 40,
          earnedCredits: 20,
          missingCredits: 20,
          isDirectory: true,
          children: [
            AcademicCategory(
              name: '通识必修课',
              reqCredits: 30,
              earnedCredits: 15,
              missingCredits: 15,
              courses: [
                AcademicCourse(
                  academicYear: '2025-2026',
                  term: '2',
                  courseCode: '3003G0002',
                  name: '大学体育(II)',
                  hours: '实践(2.0)',
                  nature: '必修',
                  credit: '1.0',
                  category: '通识必修课',
                  maxScore: '100',
                  gradePoint: '4.0',
                  score: '90',
                ),
              ],
            ),
          ],
        ),
      ],
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'grade_cache': jsonEncode({
        'grades': <Object>[],
        'years': <Object>[],
        'termsByYear': <String, Object>{},
      }),
      'grade_cache_time': now,
      'academic_cache': jsonEncode(academic.toJson()),
      'academic_cache_time': now,
    });
    final storage = PreferencesStorage();
    await storage.init();

    await tester.pumpWidget(
      _testApp(
        GradeQueryPage(
          studentId: 'test',
          password: 'test',
          preferencesStorage: storage,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('学业总览'));
    await tester.pumpAndSettle();

    expect(find.text('通识教育平台'), findsOneWidget);
    expect(find.text('通识必修课'), findsOneWidget);
    expect(find.text('成绩学年'), findsNothing);
    expect(find.text('大学体育(II)'), findsNothing);

    await tester.tap(find.text('通识必修课'));
    await tester.pumpAndSettle();

    expect(find.text('成绩学年'), findsOneWidget);
    expect(find.text('课程名称'), findsOneWidget);
    expect(find.text('大学体育(II)'), findsOneWidget);
  });
}

Widget _testApp(Widget home) => MaterialApp(
  localizationsDelegates: FLocalizations.localizationsDelegates,
  supportedLocales: FLocalizations.supportedLocales,
  builder: (context, child) => FTheme(data: AppTheme.light, child: child!),
  home: home,
);
