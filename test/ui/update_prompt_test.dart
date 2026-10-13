import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xzitpocket/services/control_service.dart';
import 'package:xzitpocket/ui/app_theme.dart';
import 'package:xzitpocket/ui/update_prompt.dart';

Widget _host(Widget page) => MaterialApp(
  localizationsDelegates: FLocalizations.localizationsDelegates,
  supportedLocales: FLocalizations.supportedLocales,
  builder: (context, child) => FTheme(
    data: AppTheme.light,
    child: FToaster(child: FTooltipGroup(child: child!)),
  ),
  home: page,
);

void main() {
  testWidgets('update page stacks the download module above the changelog', (
    tester,
  ) async {
    final release = ControlRelease(
      latestVersion: '2.0.4',
      downloadUrl: Uri.parse('https://xuda.live/app.apk'),
      changelog: '## 本次更新\n- 新增更新日志页面',
    );

    await tester.pumpWidget(
      _host(AppUpdatePage(release: release, currentVersion: '1.9.0')),
    );
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
    // 上方下载模块：只有一个「下载并安装」按钮，无标题卡片。
    expect(find.text('下载并安装'), findsOneWidget);
    // 按钮上方显示「当前版本 → 最新版本」。
    expect(find.text('1.9.0 → 2.0.4'), findsOneWidget);
    expect(find.text('新版本 2.0.4'), findsNothing);
    // 下方更新日志模块（统一 Markdown 组件渲染）。
    expect(find.text('更新日志'), findsOneWidget);
    expect(find.textContaining('新增更新日志页面'), findsOneWidget);
    // 不再有「我知道了」/「立即更新」按钮，也不自动弹出。
    expect(find.text('我知道了'), findsNothing);
    expect(find.text('立即更新'), findsNothing);
  });

  testWidgets('empty changelog falls back to a placeholder', (tester) async {
    final release = ControlRelease(
      latestVersion: '2.0.5',
      downloadUrl: Uri.parse('https://xuda.live/app.apk'),
    );

    await tester.pumpWidget(_host(AppUpdatePage(release: release)));
    await tester.pumpAndSettle();

    expect(find.text('暂无更新日志'), findsOneWidget);
    expect(find.text('下载并安装'), findsOneWidget);
  });
}
