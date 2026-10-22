import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xzitpocket/ui/app_components.dart';
import 'package:xzitpocket/ui/app_theme.dart';

void main() {
  Widget host(Widget child) => FTheme(
    data: AppTheme.light,
    child: MaterialApp(home: Scaffold(body: child)),
  );

  testWidgets('destructive dialog uses flat text actions and cancels', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showAppConfirmDialog(
                context: context,
                title: '删除课程',
                message: '仅删除第 3 周的这次课程。',
                confirmLabel: '删除',
                destructive: true,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('删除课程'), findsOneWidget);
    expect(find.text('仅删除第 3 周的这次课程。'), findsOneWidget);
    // Option 1 keeps the dialog flat: text actions only, no filled buttons.
    expect(find.byType(FButton), findsNothing);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('删除课程'), findsNothing);
    expect(result, isFalse);
  });

  testWidgets('benign dialog uses flat text actions and confirms', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showAppConfirmDialog(
                context: context,
                title: '解绑设备',
                message: '确定要解绑此设备吗？',
                confirmLabel: '解绑',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(FButton), findsNothing);

    await tester.tap(find.text('解绑'));
    await tester.pumpAndSettle();
    expect(find.text('解绑设备'), findsNothing);
    expect(result, isTrue);
  });
}
