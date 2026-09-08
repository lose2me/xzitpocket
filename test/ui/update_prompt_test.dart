import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xzitpocket/services/control_service.dart';
import 'package:xzitpocket/ui/app_theme.dart';
import 'package:xzitpocket/ui/update_prompt.dart';

void main() {
  testWidgets('startup update prompt shows the release and can be deferred', (
    tester,
  ) async {
    final release = ControlRelease(
      latestVersion: '2.0.4',
      downloadUrl: Uri.parse('https://xuda.live/app.apk'),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: FLocalizations.localizationsDelegates,
        supportedLocales: FLocalizations.supportedLocales,
        builder: (context, child) => FTheme(
          data: AppTheme.light,
          child: FToaster(child: FTooltipGroup(child: child!)),
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showAppUpdatePrompt(context: context, release: release),
            child: const Text('检查更新'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.byType(FDialog), findsOneWidget);
    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.textContaining('2.0.4'), findsOneWidget);

    await tester.tap(find.text('稍后'));
    await tester.pumpAndSettle();
    expect(find.byType(FDialog), findsNothing);
  });
}
