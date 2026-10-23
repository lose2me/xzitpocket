import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../providers/config_provider.dart';
import '../../ui/app_components.dart';
import 'about_markdown.dart';

/// First-run disclaimer. Shown only while `disclaimer_accepted` is unset.
/// Accepting persists the flag permanently; it is never cleared by
/// personalization resets, version migrations, or logout. Declining does not
/// persist anything and force-closes the app; on the next launch the page
/// reappears. There is no back button and no system-back escape: the user
/// must pick one of the two buttons.
class DisclaimerPage extends ConsumerStatefulWidget {
  /// 首次安装的合规门禁为 true：显示「拒绝 / 同意并继续」。
  ///
  /// 从「附加页面」进入时传 false，仅作阅读，页面内不出现任何确认/取消按钮。
  final bool showActions;

  const DisclaimerPage({super.key, this.showActions = true});

  @override
  ConsumerState<DisclaimerPage> createState() => _DisclaimerPageState();
}

class _DisclaimerPageState extends ConsumerState<DisclaimerPage> {
  @override
  Widget build(BuildContext context) {
    final showActions = widget.showActions;
    return PopScope(
      canPop: !showActions,
      child: AppPage(
        title: '免责声明',
        showBackButton: !showActions,
        child: AppPageListView(
          showScrollbar: true,
          children: [
            const AboutMarkdown(asset: 'assets/about/disclaimer.md'),
            // 首次安装才需要做出选择；阅读入口不显示任何按钮。
            if (showActions) ...[
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: FButton(
                      variant: FButtonVariant.secondary,
                      onPress: () => SystemNavigator.pop(),
                      child: const Text('拒绝'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FButton(
                      onPress: () => unawaited(_accept()),
                      child: const Text('同意并继续'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _accept() async {
    final navigator = Navigator.of(context);
    await ref.read(preferencesStorageProvider).setDisclaimerAccepted(true);
    // 返回 true，首页据此跳转到登录页（「我的」标签）。
    navigator.pop(true);
  }
}
