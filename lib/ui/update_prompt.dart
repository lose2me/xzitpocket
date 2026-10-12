import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../services/control_service.dart';
import 'app_components.dart';
import 'app_markdown.dart';

/// 打开更新页：展示发布更新日志，仅一个「我知道了」按钮。
/// 点击 = 忽略本次更新并关闭（由 [onAcknowledged] 持久化已忽略版本）；
/// 出现更新版本时会再次提醒。下载/安装仍由「我的 → 发现新版本」承担，
/// 更新页不包含任何下载逻辑。
Future<void> showAppUpdatePrompt({
  required BuildContext context,
  required ControlRelease release,
  VoidCallback? onAcknowledged,
}) => Navigator.of(context).push(
  appRoute(
    name: '/about/app-update',
    fullscreenDialog: true,
    builder: (_) =>
        AppUpdatePage(release: release, onAcknowledged: onAcknowledged),
  ),
);

class AppUpdatePage extends StatelessWidget {
  final ControlRelease release;
  final VoidCallback? onAcknowledged;

  const AppUpdatePage({super.key, required this.release, this.onAcknowledged});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final changelog = release.changelog.trim();
    return AppPage(
      title: '发现新版本',
      footer: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FButton(
              onPress: () {
                onAcknowledged?.call();
                Navigator.of(context).pop();
              },
              child: const Text('我知道了'),
            ),
          ),
        ),
      ),
      child: AppPageListView(
        children: [
          Text(
            '版本 ${release.latestVersion} 已发布',
            style: theme.typography.pageTitle,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (changelog.isEmpty)
            Text(
              '暂无更新日志',
              style: theme.typography.bodySmall.copyWith(
                color: theme.colors.mutedForeground,
              ),
            )
          else
            AppMarkdown(data: changelog),
        ],
      ),
    );
  }
}
