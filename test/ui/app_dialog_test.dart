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

  Future<void> openDialog(
    WidgetTester tester, {
    required bool destructive,
    required void Function(bool) onResult,
  }) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              onResult(
                await showAppConfirmDialog(
                  context: context,
                  title: '删除这节课？',
                  message: '仅删除第 3 周的这次课程。',
                  confirmLabel: '删除',
                  destructive: destructive,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('confirm dialog uses the split text footer', (tester) async {
    bool? result;
    await openDialog(
      tester,
      destructive: true,
      onResult: (value) => result = value,
    );

    expect(find.text('删除这节课？'), findsOneWidget);
    expect(find.text('仅删除第 3 周的这次课程。'), findsOneWidget);
    // The reference design has no filled buttons, only the split footer.
    expect(find.byType(FButton), findsNothing);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('confirm dialog returns true from the confirm action', (
    tester,
  ) async {
    bool? result;
    await openDialog(
      tester,
      destructive: false,
      onResult: (value) => result = value,
    );

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
