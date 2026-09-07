import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/models/learning_question.dart';
import 'package:xzitpocket/pages/tools/learning_center_page.dart';
import 'package:xzitpocket/services/learning_repository.dart';
import 'package:xzitpocket/services/preferences_storage.dart';
import 'package:xzitpocket/ui/app_theme.dart';
import 'package:xzitpocket/pages/tools/learning_quiz_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const remoteQuestion = LearningQuestion(
    id: 'remote-1',
    bankName: '在线题库',
    bankId: 'QB-REMOTE',
    bankOrderId: 1,
    bankIsNew: true,
    questionNumber: 1,
    title: '第1题',
    questionText: '在线题目',
    type: LearningQuestionType.single,
    options: [
      LearningOption(id: 'A', text: '正确答案'),
      LearningOption(id: 'B', text: '其他答案'),
    ],
    correctOptionIds: {'A'},
  );

  Future<PreferencesStorage> storage() async {
    SharedPreferences.setMockInitialValues({});
    final value = PreferencesStorage();
    await value.init();
    return value;
  }

  Future<void> pumpCenter(
    WidgetTester tester,
    LearningRepository repository,
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
          home: LearningCenterPage(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows online learning questions and navigation', (tester) async {
    var fetchCount = 0;
    final repository = LearningRepository(
      preferencesStorage: await storage(),
      fetcher: () async {
        fetchCount++;
        return [remoteQuestion];
      },
    );

    await pumpCenter(tester, repository);

    expect(find.text('在线题库'), findsOneWidget);
    // A single term is displayed without a redundant section heading.
    expect(find.text('最新题库'), findsNothing);
    expect(find.text('题库'), findsWidgets);
    expect(find.text('错题集'), findsOneWidget);
    expect(find.text('收藏集'), findsOneWidget);
    expect(find.text('兑换通用 CDK'), findsNothing);
    expect(find.byType(FTile), findsOneWidget);
    expect(find.byIcon(FLucideIcons.refreshCw), findsOneWidget);

    await tester.tap(find.byIcon(FLucideIcons.refreshCw));
    await tester.pump();
    expect(fetchCount, 2);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('groups banks and opens CDK sheet from a locked bank', (
    tester,
  ) async {
    final repository = LearningRepository(
      preferencesStorage: await storage(),
      bankFetcher: () async => [
        const LearningQuestionBank(
          id: 'QB-NEW',
          name: '形势与政策',
          isNew: true,
          orderId: 1,
          requiresCDK: true,
          locked: true,
          questions: [],
        ),
        const LearningQuestionBank(
          id: 'QB-OLD',
          name: '2024 马原',
          isNew: false,
          orderId: 2,
          questions: [remoteQuestion],
        ),
      ],
      cdkRedeemer: (code, bankId) async {},
    );

    await pumpCenter(tester, repository);

    expect(find.text('最新题库'), findsOneWidget);
    expect(find.text('往年题库'), findsOneWidget);
    expect(find.text('形势与政策'), findsOneWidget);
    expect(find.text('2024 马原'), findsOneWidget);
    expect(find.text('兑换通用 CDK'), findsNothing);
    expect(find.text('解锁题库'), findsNothing);

    await tester.tap(find.text('形势与政策'));
    await tester.pumpAndSettle();

    expect(find.byType(FDialog), findsOneWidget);
    expect(find.text('解锁题库'), findsOneWidget);
    expect(find.text('「形势与政策」需要 CDK 解锁后才能练习'), findsOneWidget);
    expect(find.text('输入 CDK'), findsOneWidget);
  });

  testWidgets(
    'wrong collection shows counts and removes a corrected question',
    (tester) async {
      final repository = LearningRepository(
        preferencesStorage: await storage(),
        fetcher: () async => [remoteQuestion],
      );
      await repository.load();
      await repository.submitAnswer(remoteQuestion.id, {'B'});

      await pumpCenter(tester, repository);
      await tester.tap(find.text('错题集'));
      await tester.pumpAndSettle();

      expect(find.text('最新题库'), findsNothing);
      expect(find.text('往年题库'), findsNothing);
      expect(find.text('1'), findsOneWidget);

      await tester.tap(
        find.ancestor(of: find.text('在线题库'), matching: find.byType(FTile)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('正确答案'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(repository.wrongIds, isNot(contains(remoteQuestion.id)));
    },
  );

  testWidgets('favorite banks open in flow mode and can be removed', (
    tester,
  ) async {
    final repository = LearningRepository(
      preferencesStorage: await storage(),
      fetcher: () async => [remoteQuestion],
    );
    await repository.load();
    await repository.toggleFavorite(remoteQuestion.id);

    await pumpCenter(tester, repository);
    await tester.tap(find.text('收藏集'));
    await tester.pumpAndSettle();

    expect(find.text('最新题库'), findsNothing);
    expect(find.text('往年题库'), findsNothing);
    expect(find.byIcon(FLucideIcons.x), findsOneWidget);

    await tester.tap(find.text('在线题库'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<LearningQuizPage>(find.byType(LearningQuizPage)).mode,
      LearningQuizMode.memorizeFlow,
    );

    Navigator.of(tester.element(find.byType(LearningQuizPage))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(FLucideIcons.x));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(repository.favoriteIds, isNot(contains(remoteQuestion.id)));
    expect(find.text('在线题库'), findsNothing);
  });
}
