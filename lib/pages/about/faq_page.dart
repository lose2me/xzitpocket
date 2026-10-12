import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../ui/app_components.dart';

/// Static FAQ page. Deliberately has no in-page action buttons; navigation
/// back happens through the AppBar back action or the system back gesture.
class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return AppPage(
      title: '常见问题',
      child: AppPageListView(
        children: [
          _buildEntry(
            theme,
            question: '登录后课表没有数据怎么办？',
            answer:
                '课表数据依赖校园网环境，请确认已连接校园 WiFi 后，'
                '在课表页下拉或点击刷新按钮重新同步。',
          ),
          _buildEntry(
            theme,
            question: '电费 / 一卡通查询失败？',
            answer:
                '这些功能同样需要在校园网内使用；若提示缓存数据，'
                '说明当前不在校园网环境，显示的是最近一次成功查询的结果。',
          ),
          _buildEntry(
            theme,
            question: '桌面小组件不更新？',
            answer:
                '请检查是否授予了应用后台刷新权限，或在个性化设置中调整小组件样式后，'
                '小组件会自动触发一次刷新。',
          ),
        ],
      ),
    );
  }

  Widget _buildEntry(
    FThemeData theme, {
    required String question,
    required String answer,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: theme.typography.bodyText),
          const SizedBox(height: 8),
          Text(
            answer,
            style: theme.typography.bodySmall.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
