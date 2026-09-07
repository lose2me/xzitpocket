import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/models/learning_question.dart';
import 'package:xzitpocket/pages/tools/learning_quiz_page.dart';
import 'package:xzitpocket/services/learning_repository.dart';
import 'package:xzitpocket/services/preferences_storage.dart';
import 'package:xzitpocket/ui/app_colors.dart';
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

  testWidgets('multiple choice AC keeps A green until C completes the answer', (
    tester,
  ) async {
    const multiple = LearningQuestion(
      id: 'multi-ac',
      questionNumber: 1,
      title: '多选题 AC',
      questionText: '请选择 A、C',
      type: LearningQuestionType.multiple,
      options: [
        LearningOption(id: 'A', text: '选项 A'),
        LearningOption(id: 'B', text: '选项 B'),
        LearningOption(id: 'C', text: '选项 C'),
      ],
      correctOptionIds: {'A', 'C'},
    );
    final repository = await createRepository([multiple, second]);
    await pumpQuiz(tester, repository, const ['multi-ac', 'q2']);

    await tester.tap(find.text('选项 A'));
    await tester.pump();

    expect(repository.isJudged('multi-ac'), isFalse);
    final optionContainers = tester.widgetList<Container>(
      find.ancestor(of: find.text('选项 A'), matching: find.byType(Container)),
    );
    expect(
      optionContainers.any((container) {
        final decoration = container.decoration;
        return decoration is BoxDecoration &&
            decoration.color == AppTheme.light.colors.semantic.successContainer;
      }),
      isTrue,
    );

    await tester.tap(find.text('选项 C'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(repository.isCorrect('multi-ac'), isTrue);
  });

  testWidgets(
    'swiping can browse unanswered questions and review previous ones',
    (tester) async {
      final repository = await createRepository([first, second]);
      await pumpQuiz(tester, repository, const ['q1', 'q2']);

      await tester.fling(
        find.textContaining('第一题题干'),
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('第一题题干'), findsNothing);
      expect(find.textContaining('第二题题干'), findsOneWidget);

      await tester.fling(
        find.textContaining('第二题题干'),
        const Offset(300, 0),
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

  testWidgets('empty fill answer remains unjudged when swiping forward', (
    tester,
  ) async {
    const fill = LearningQuestion(
      id: 'empty-fill',
      questionNumber: 1,
      title: '空填空题',
      questionText: 'Flutter 使用 ____ 语言',
      type: LearningQuestionType.fillBlank,
      options: [],
      correctOptionIds: {'Dart'},
    );
    final repository = await createRepository([fill, second]);
    await pumpQuiz(tester, repository, const ['empty-fill', 'q2']);

    await tester.fling(
      find.textContaining('Flutter 使用'),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(repository.isJudged('empty-fill'), isFalse);
    expect(find.textContaining('第二题题干'), findsOneWidget);
  });

  testWidgets('empty fill answer can move forward with the next button', (
    tester,
  ) async {
    const fill = LearningQuestion(
      id: 'empty-fill-button',
      questionNumber: 1,
      title: '空填空按钮题',
      questionText: 'Flutter 使用 ____ 语言',
      type: LearningQuestionType.fillBlank,
      options: [],
      correctOptionIds: {'Dart'},
    );
    final repository = await createRepository([fill, second]);
    await pumpQuiz(tester, repository, const ['empty-fill-button', 'q2']);

    await tester.tap(find.text('下一题'));
    await tester.pumpAndSettle();

    expect(repository.isJudged('empty-fill-button'), isFalse);
    expect(find.textContaining('第二题题干'), findsOneWidget);
  });

  testWidgets('random mode previous follows the shuffled page sequence', (
    tester,
  ) async {
    final repository = await createRepository([first, second]);
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
          home: LearningQuizPage(
            repository: repository,
            questionIds: const ['q1', 'q2'],
            mode: LearningQuizMode.random,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final firstPage = find.textContaining('第一题题干').evaluate().isNotEmpty;
    final secondPage = find.textContaining('第二题题干').evaluate().isNotEmpty;
    expect(firstPage || secondPage, isTrue);

    final currentQuestion = firstPage ? '第一题题干' : '第二题题干';
    final previousQuestion = firstPage ? '第二题题干' : '第一题题干';
    await tester.fling(
      find.textContaining(currentQuestion),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(previousQuestion), findsOneWidget);

    await tester.fling(
      find.textContaining(previousQuestion),
      const Offset(300, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(currentQuestion), findsOneWidget);
  });
}
