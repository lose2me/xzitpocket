import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/models/learning_question.dart';
import 'package:xzitpocket/pages/tools/learning_quiz_page.dart';
import 'package:xzitpocket/services/learning_repository.dart';
import 'package:xzitpocket/services/preferences_storage.dart';
import 'package:xzitpocket/ui/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<LearningRepository> createRepository(
    List<LearningQuestion> questions,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = PreferencesStorage();
    await storage.init();
    final repository = LearningRepository(
      preferencesStorage: storage,
      fetcher: () async => questions,
    );
    await repository.load();
    return repository;
  }

  Future<void> pumpQuiz(
    WidgetTester tester,
    LearningRepository repository,
    List<String> ids,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: MaterialApp(
          localizationsDelegates: FLocalizations.localizationsDelegates,
          supportedLocales: FLocalizations.supportedLocales,
          builder: (context, child) => FTheme(
            data: AppTheme.light,
            child: FToaster(child: FTooltipGroup(child: child!)),
          ),
          home: LearningQuizPage(repository: repository, questionIds: ids),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const first = LearningQuestion(
    id: 'q1',
    questionNumber: 1,
    title: '第一题',
    questionText: '第一题题干',
    type: LearningQuestionType.single,
    options: [
      LearningOption(id: 'A', text: '正确选项'),
      LearningOption(id: 'B', text: '错误选项'),
    ],
    correctOptionIds: {'A'},
  );
  const second = LearningQuestion(
    id: 'q2',
    questionNumber: 2,
    title: '第二题',
    questionText: '第二题题干',
    type: LearningQuestionType.single,
    options: [
      LearningOption(id: 'A', text: '第二题正确选项'),
      LearningOption(id: 'B', text: '第二题错误选项'),
    ],
    correctOptionIds: {'A'},
  );

  testWidgets('wrong option is judged immediately and remains on question', (
    tester,
  ) async {
    final repository = await createRepository([first, second]);
    await pumpQuiz(tester, repository, const ['q1', 'q2']);

    await tester.tap(find.text('错误选项'));
    await tester.pumpAndSettle();

    expect(repository.isJudged('q1'), isTrue);
    expect(repository.isCorrect('q1'), isFalse);
    expect(find.textContaining('第一题题干'), findsOneWidget);
    expect(find.text('正确选项'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('correct option advances and keeps header state synchronized', (
    tester,
  ) async {
    final repository = await createRepository([first, second]);
    await pumpQuiz(tester, repository, const ['q1', 'q2']);

    await tester.tap(find.text('正确选项'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(repository.isCorrect('q1'), isTrue);
    expect(find.textContaining('第二题题干'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('multiple choice waits while selection is a correct subset', (
    tester,
  ) async {
    const multiple = LearningQuestion(
      id: 'multi',
      questionNumber: 1,
      title: '多选题',
      questionText: '请选择两个正确选项',
      type: LearningQuestionType.multiple,
      options: [
        LearningOption(id: 'A', text: '选项 A'),
        LearningOption(id: 'B', text: '选项 B'),
        LearningOption(id: 'C', text: '选项 C'),
      ],
      correctOptionIds: {'A', 'B'},
    );
    final repository = await createRepository([multiple, second]);
    await pumpQuiz(tester, repository, const ['multi', 'q2']);

    await tester.tap(find.text('选项 A'));
    await tester.pump();
    expect(repository.isJudged('multi'), isFalse);

    await tester.tap(find.text('选项 B'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(repository.isCorrect('multi'), isTrue);
    expect(find.textContaining('第二题题干'), findsOneWidget);
  });

  testWidgets(
    'swiping cannot open unanswered questions but can review judged ones',
    (tester) async {
      final repository = await createRepository([first, second]);
      await pumpQuiz(tester, repository, const ['q1', 'q2']);

      await tester.fling(
        find.textContaining('第一题题干'),
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('第一题题干'), findsOneWidget);
      expect(find.textContaining('第二题题干'), findsNothing);

      await tester.tap(find.text('正确选项'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.textContaining('第二题题干'), findsOneWidget);

      await tester.fling(
        find.textContaining('第二题题干'),
        const Offset(300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('第一题题干'), findsOneWidget);
    },
  );

  testWidgets('wrong fill answer stays visible with the correct answer', (
    tester,
  ) async {
    const fill = LearningQuestion(
      id: 'fill',
      questionNumber: 1,
      title: '填空题',
      questionText: 'Flutter 使用 ____ 语言',
      type: LearningQuestionType.fillBlank,
      options: [],
      correctOptionIds: {'Dart'},
    );
    final repository = await createRepository([fill, second]);
    await pumpQuiz(tester, repository, const ['fill', 'q2']);

    await tester.enterText(find.byType(TextField), 'Java');
    await tester.tap(find.text('下一题'));
    await tester.pumpAndSettle();

    expect(repository.isJudged('fill'), isTrue);
    expect(repository.isCorrect('fill'), isFalse);
    expect(find.textContaining('Flutter 使用'), findsOneWidget);
    expect(find.text('正确答案：Dart'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });
}
