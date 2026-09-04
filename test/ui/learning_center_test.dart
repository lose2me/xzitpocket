import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/models/learning_question.dart';
import 'package:xzitpocket/pages/tools/learning_center_page.dart';
import 'package:xzitpocket/services/learning_repository.dart';
import 'package:xzitpocket/services/preferences_storage.dart';
import 'package:xzitpocket/ui/app_components.dart';
import 'package:xzitpocket/ui/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows online learning questions and navigation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = PreferencesStorage();
    await storage.init();
    final repository = LearningRepository(
      preferencesStorage: storage,
      fetcher: () async => [
        const LearningQuestion(
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
        ),
      ],
    );

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

    expect(find.text('在线题库'), findsOneWidget);
    expect(find.text('题库'), findsWidgets);
    expect(find.text('错题集'), findsOneWidget);
    expect(find.text('收藏集'), findsOneWidget);
    expect(find.byType(AppCard), findsOneWidget);
  });
}
