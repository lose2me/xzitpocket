import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/models/resource_center.dart';
import 'package:xzitpocket/pages/tools/resource_upload_page.dart';
import 'package:xzitpocket/services/preferences_storage.dart';
import 'package:xzitpocket/ui/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PreferencesStorage> storage() async {
    SharedPreferences.setMockInitialValues({});
    final value = PreferencesStorage();
    await value.init();
    return value;
  }

  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: FLocalizations.localizationsDelegates,
    supportedLocales: FLocalizations.supportedLocales,
    builder: (context, content) =>
        FTheme(data: AppTheme.light, child: content!),
    home: child,
  );

  ResourceUploadPage page(
    PreferencesStorage preferencesStorage, {
    bool courseScoped = false,
    Future<List<UploadTextbook>> Function(String courseCode)? loadTextbooks,
  }) => ResourceUploadPage(
    courses: const [ResourceCourse(code: 'C1', name: '高等数学')],
    initialKind: 'textbook',
    initialCourseCode: 'C1',
    courseScoped: courseScoped,
    preferencesStorage: preferencesStorage,
    loadTextbooks: loadTextbooks ?? (_) async => const [],
  );

  // The page shows two labels with this text: the textbook selector and the
  // file picker below it. The selector label must always exist.
  final textbookLabels = find.text('选择教材');

  testWidgets('keeps the textbook field and label while loading', (
    tester,
  ) async {
    final preferencesStorage = await storage();
    final pending = Completer<List<UploadTextbook>>();
    await tester.pumpWidget(
      wrap(page(preferencesStorage, loadTextbooks: (_) => pending.future)),
    );

    // The first frame is the loading state: a field, not a spinner, so the
    // form does not flash or change height when the list arrives.
    expect(textbookLabels, findsNWidgets(2));
    expect(find.text('正在加载教材…'), findsOneWidget);
    expect(find.byType(FCircularProgress), findsNothing);

    pending.complete(const []);
    await tester.pumpAndSettle();
    expect(textbookLabels, findsNWidgets(2));
    expect(find.text('暂无可选教材'), findsOneWidget);
  });

  testWidgets('an empty list keeps the field style and shows a hint', (
    tester,
  ) async {
    final preferencesStorage = await storage();
    await tester.pumpWidget(wrap(page(preferencesStorage)));
    await tester.pumpAndSettle();

    expect(textbookLabels, findsNWidgets(2));
    expect(find.text('暂无可选教材'), findsOneWidget);
    expect(find.text('该课程暂无关联教材'), findsNothing);
  });

  testWidgets('a course-scoped empty list explains the course has no books', (
    tester,
  ) async {
    final preferencesStorage = await storage();
    await tester.pumpWidget(
      wrap(page(preferencesStorage, courseScoped: true)),
    );
    await tester.pumpAndSettle();

    expect(textbookLabels, findsNWidgets(2));
    expect(find.text('该课程暂无关联教材'), findsOneWidget);
  });

  testWidgets('lists the textbooks under the label once loaded', (
    tester,
  ) async {
    final preferencesStorage = await storage();
    await tester.pumpWidget(
      wrap(
        page(
          preferencesStorage,
          loadTextbooks: (_) async => const [
            UploadTextbook(id: 'tb-1', name: '高等数学（上）', courseCodes: ['C1']),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(textbookLabels, findsNWidgets(2));
    expect(find.textContaining('高等数学（上）'), findsOneWidget);
    expect(find.text('暂无可选教材'), findsNothing);
  });

  testWidgets('cached textbooks preselect the first book under the label', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'resource_upload_textbooks_cache': jsonEncode([
        {
          'id': 'tb-1',
          'name': '高等数学（上）',
          'tags': '高教社',
          'course_codes': ['C1'],
          'has_pdf': true,
        },
      ]),
      'resource_upload_textbooks_cache_time':
          DateTime.now().millisecondsSinceEpoch,
    });
    final preferencesStorage = PreferencesStorage();
    await preferencesStorage.init();
    await tester.pumpWidget(wrap(page(preferencesStorage)));
    await tester.pumpAndSettle();

    expect(textbookLabels, findsNWidgets(2));
    expect(find.textContaining('高等数学（上）'), findsOneWidget);
    expect(find.text('暂无可选教材'), findsNothing);
  });
}
