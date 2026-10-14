import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../providers/config_provider.dart';
import '../../ui/app_components.dart';
import '../../ui/app_markdown.dart';

/// First-run disclaimer. Shown only while `disclaimer_accepted` is unset.
/// Accepting persists the flag permanently; it is never cleared by
/// personalization resets, version migrations, or logout. Declining does not
/// persist anything and force-closes the app; on the next launch the page
/// reappears. There is no back button and no system-back escape: the user
/// must pick one of the two buttons.
class DisclaimerPage extends ConsumerStatefulWidget {
  const DisclaimerPage({super.key});

  @override
  ConsumerState<DisclaimerPage> createState() => _DisclaimerPageState();
}

class _DisclaimerPageState extends ConsumerState<DisclaimerPage> {
  static const _termsAsset = 'assets/about/disclaimer.md';
  String? _terms;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTerms());
  }

  Future<void> _loadTerms() async {
    final content = await rootBundle.loadString(_termsAsset);
    if (mounted) setState(() => _terms = content);
  }

  @override
  Widget build(BuildContext context) {
    final terms = _terms;
    return PopScope(
      canPop: false,
      child: AppPage(
        title: '免责声明',
        showBackButton: false,
        child: AppPageListView(
          showScrollbar: true,
          children: [
            if (terms != null) AppMarkdown(data: terms),
            // 按钮紧跟文章最下面（非固定底栏），不加额外样式。
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
