import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../providers/config_provider.dart';
import '../../ui/app_components.dart';

/// First-run disclaimer. Shown only while `disclaimer_accepted` is unset.
/// Accepting persists the flag permanently; it is never cleared by
/// personalization resets, version migrations, or logout. Declining does not
/// persist anything, so the page reappears on the next launch.
class DisclaimerPage extends ConsumerWidget {
  const DisclaimerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    return PopScope(
      canPop: false,
      child: AppPage(
        title: '免责声明',
        footer: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: FButton(
                    variant: FButtonVariant.secondary,
                    onPress: () => Navigator.of(context).pop(),
                    child: const Text('拒绝'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FButton(
                    onPress: () => unawaited(_accept(context, ref)),
                    child: const Text('同意并继续'),
                  ),
                ),
              ],
            ),
          ),
        ),
        child: AppPageListView(
          children: [
            Text(
              '欢迎使用掌上徐工。在使用本应用前，请仔细阅读以下条款：',
              style: theme.typography.bodyText,
            ),
            const SizedBox(height: 16),
            Text(
              '1. 本应用为校园信息服务工具，数据来源于学校各业务系统，'
              '准确性与时效性以学校官方发布为准。\n\n'
              '2. 本应用不收集与业务无关的个人隐私信息，账号凭据仅保存在设备本地。\n\n'
              '3. 因网络、系统维护或数据源变更导致的服务中断或数据差异，'
              '本应用不承担相应责任。\n\n'
              '4. 继续使用即表示您已理解并同意上述条款。',
              style: theme.typography.bodyText.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    await ref.read(preferencesStorageProvider).setDisclaimerAccepted(true);
    navigator.pop();
  }
}
