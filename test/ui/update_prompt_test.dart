import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xzitpocket/services/control_service.dart';
import 'package:xzitpocket/ui/app_theme.dart';
import 'package:xzitpocket/ui/update_prompt.dart';

Widget _host(Future<void> Function(BuildContext context) onTrigger) =>
    MaterialApp(
      localizationsDelegates: FLocalizations.localizationsDelegates,
      supportedLocales: FLocalizations.supportedLocales,
      builder: (context, child) => FTheme(
        data: AppTheme.light,
        child: FToaster(child: FTooltipGroup(child: child!)),
      ),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => onTrigger(context),
          child: const Text('检查更新'),
        ),
      ),
    );

void main() {
  testWidgets('update page shows the changelog and one acknowledge button', (
    tester,
  ) async {
    var acknowledged = 0;
    final release = ControlRelease(
      latestVersion: '2.0.4',
      downloadUrl: Uri.parse('https://xuda.live/app.apk'),
      changelog: '## 本次更新\n- 新增更新日志页面',
    );

    await tester.pumpWidget(
      _host(
        (context) => showAppUpdatePrompt(
          context: context,
          release: release,
          onAcknowledged: () => acknowledged++,
        ),
      ),
    );

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.textContaining('2.0.4'), findsOneWidget);
    // Markdown 更新日志经由统一组件渲染。
    expect(find.textContaining('新增更新日志页面'), findsOneWidget);
    // 仅一个「我知道了」按钮；「立即更新」「稍后」均已取消。
    expect(find.text('我知道了'), findsOneWidget);
    expect(find.text('立即更新'), findsNothing);
    expect(find.text('稍后'), findsNothing);

    await tester.tap(find.text('我知道了'));
    await tester.pumpAndSettle();
    expect(acknowledged, 1);
    expect(find.text('发现新版本'), findsNothing);
  });

  testWidgets('empty changelog falls back to a placeholder', (tester) async {
    final release = ControlRelease(
      latestVersion: '2.0.5',
      downloadUrl: Uri.parse('https://xuda.live/app.apk'),
    );

    await tester.pumpWidget(
      _host(
        (context) => showAppUpdatePrompt(context: context, release: release),
      ),
    );

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    expect(find.text('暂无更新日志'), findsOneWidget);
  });
}
