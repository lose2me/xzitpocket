import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/pages/about/disclaimer_page.dart';
import 'package:xzitpocket/pages/about/faq_page.dart';
import 'package:xzitpocket/providers/config_provider.dart';
import 'package:xzitpocket/services/preferences_storage.dart';
import 'package:xzitpocket/ui/app_theme.dart';

void main() {
  late PreferencesStorage prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = PreferencesStorage();
    await prefs.init();
  });

  Widget host(Widget page) => ProviderScope(
    overrides: [preferencesStorageProvider.overrideWithValue(prefs)],
    child: FTheme(
      data: AppTheme.light,
      child: MaterialApp(home: page),
    ),
  );

  testWidgets('accepting the disclaimer persists the flag permanently', (
    tester,
  ) async {
    await tester.pumpWidget(host(const DisclaimerPage()));
    expect(find.text('免责声明'), findsOneWidget);
    // 左上角没有返回按钮。
    expect(find.byType(FHeaderAction), findsNothing);

    await tester.tap(find.text('同意并继续'));
    await tester.pumpAndSettle();

    expect(prefs.getDisclaimerAccepted(), isTrue);
  });

  testWidgets('declining force-closes the app and persists nothing', (
    tester,
  ) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call.method);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(host(const DisclaimerPage()));

    await tester.tap(find.text('拒绝'));
    await tester.pumpAndSettle();

    expect(calls, contains('SystemNavigator.pop'));
    expect(prefs.getDisclaimerAccepted(), isFalse);
  });

  testWidgets('FAQ page has no in-page action buttons', (tester) async {
    await tester.pumpWidget(host(const FaqPage()));
    await tester.pumpAndSettle();

    expect(find.text('常见问题'), findsOneWidget);
    expect(find.byType(FButton), findsNothing);
    expect(find.text('登录后课表没有数据怎么办？'), findsOneWidget);
  });
}
