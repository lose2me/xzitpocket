import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/pages/tools/learning_center_page.dart';
import 'package:xzitpocket/services/learning_repository.dart';
import 'package:xzitpocket/services/preferences_storage.dart';
import 'package:xzitpocket/ui/app_theme.dart';
import 'package:xzitpocket/ui/app_components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows year banks and learning navigation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = PreferencesStorage();
    await storage.init();
    final repository = LearningRepository(preferencesStorage: storage);

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

    expect(find.text('题库'), findsWidgets);
    expect(find.text('错题集'), findsOneWidget);
    expect(find.text('收藏集'), findsOneWidget);
    expect(find.text('2601'), findsOneWidget);
    expect(find.text('2501'), findsOneWidget);

    await tester.tap(find.byType(AppCard).first);
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('在校园服务中发现设备故障时，最合适的第一步是什么？'), findsOneWidget);

    await tester.tap(find.text('拍照记录现场并提交报修'));
    await tester.fling(find.byType(PageView), const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();

    expect(repository.isJudged('campus-001'), isTrue);
    expect(find.text('以下哪些做法有助于保护校园账号安全？'), findsOneWidget);
  });
}
