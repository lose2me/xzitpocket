import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/pages/about/disclaimer_page.dart';
import 'package:xzitpocket/pages/about/extra_pages_page.dart';
import 'package:xzitpocket/pages/about/faq_page.dart';
import 'package:xzitpocket/providers/config_provider.dart';
import 'package:xzitpocket/services/preferences_storage.dart';
import 'package:xzitpocket/ui/app_theme.dart';

void main() {
  late PreferencesStorage prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Asset futures are cached per zone; clear them so every test gets a
    // future that can complete inside its own fake-async zone.
    rootBundle.clear();
    prefs = PreferencesStorage();
    await prefs.init();
  });

  // Markdown lives in a Future (rootBundle), so give the real event loop a
  // chance to finish before asserting on its text.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }

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

  testWidgets('read-only disclaimer has no action buttons', (tester) async {
    await tester.pumpWidget(host(const DisclaimerPage(showActions: false)));
    await tester.pumpAndSettle();

    expect(find.text('免责声明'), findsOneWidget);
    expect(find.text('同意并继续'), findsNothing);
    expect(find.text('拒绝'), findsNothing);
    expect(find.byType(FButton), findsNothing);
  });

  testWidgets('extra pages shows FAQ and the read-only disclaimer as tabs', (
    tester,
  ) async {
    await tester.pumpWidget(host(const ExtraPagesPage()));
    await settle(tester);

    expect(find.text('附加页面'), findsOneWidget);
    expect(find.text('常见问题'), findsOneWidget);
    expect(find.text('免责声明'), findsOneWidget);
    // FAQ 内容默认展示。
    expect(find.textContaining('登录所使用的账户密码是什么'), findsOneWidget);
    expect(find.byType(FButton), findsNothing);

    await tester.tap(find.text('免责声明'));
    await settle(tester);
    expect(find.textContaining('非官方应用'), findsOneWidget);
    expect(find.byType(FButton), findsNothing);
  });

  testWidgets('FAQ page has no in-page action buttons', (tester) async {
    await tester.pumpWidget(host(const FaqPage()));
    await settle(tester);

    expect(find.text('常见问题'), findsOneWidget);
    expect(find.byType(FButton), findsNothing);
    expect(find.textContaining('登录所使用的账户密码是什么'), findsOneWidget);
  });
}
