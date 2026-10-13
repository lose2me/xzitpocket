import 'package:flutter/material.dart';
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
}
