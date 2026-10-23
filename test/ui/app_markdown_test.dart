import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xzitpocket/ui/app_markdown.dart';
import 'package:xzitpocket/ui/app_theme.dart';

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: FLocalizations.localizationsDelegates,
  supportedLocales: FLocalizations.supportedLocales,
  builder: (context, c) => FTheme(data: AppTheme.light, child: c!),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('unordered list bullets follow GitHub nesting style', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const AppMarkdown(data: '- 顶层\n  - 二级\n    - 三级\n')),
    );
    await tester.pumpAndSettle();

    expect(find.text('•'), findsOneWidget);
    expect(find.text('◦'), findsOneWidget);
    expect(find.text('▪'), findsOneWidget);
  });

  test('inserts break opportunities between Latin letters', () {
    final out = AppMarkdown.withLatinBreaks('The request');
    expect(out, contains('T\u200Bh\u200Be'));
    expect(out, contains('r\u200Be\u200Bq'));
  });

  test('keeps link destinations, code spans and CJK untouched', () {
    final out = AppMarkdown.withLatinBreaks(
      '[https://ca.xzit.edu.cn/cas/login](https://ca.xzit.edu.cn/cas/login) 查看',
    );
    // The href stays byte-for-byte while its visible text may break anywhere.
    expect(out, contains('](https://ca.xzit.edu.cn/cas/login)'));
    expect(AppMarkdown.withLatinBreaks('`abc`'), '`abc`');
    expect(AppMarkdown.withLatinBreaks('中文'), '中文');
  });
}
