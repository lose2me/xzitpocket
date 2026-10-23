import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xzitpocket/ui/app_theme.dart';
import 'package:xzitpocket/utils/snackbar_helper.dart';

void main() {
  Widget testApp({required VoidCallback onPressed}) {
    return FTheme(
      data: AppTheme.light,
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              // Inside the toast band (72px navigation clearance + toast
              // height), so the toast overlays this button while visible.
              padding: const EdgeInsets.only(bottom: 84),
              child: ElevatedButton(
                onPressed: onPressed,
                child: const Text('点我'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('toast lets taps through to controls underneath', (tester) async {
    var taps = 0;
    await tester.pumpWidget(testApp(onPressed: () => taps++));

    final context = tester.element(find.text('点我'));
    showAppSnackBar(context, '测试提示');
    await tester.pump();
    await tester.pump();
    expect(find.text('测试提示'), findsOneWidget);

    await tester.tap(find.text('点我'));
    expect(taps, 1);
  });

  testWidgets('toast does not steal focus', (tester) async {
    await tester.pumpWidget(testApp(onPressed: () {}));
    final beforeFocus = FocusManager.instance.primaryFocus;

    final context = tester.element(find.byType(ElevatedButton));
    showAppSnackBar(context, '测试提示');
    await tester.pump();
    await tester.pump();

    expect(FocusManager.instance.primaryFocus, beforeFocus);
    dismissAppSnackBar();
    await tester.pump();
  });
}
