import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';

import '../../ui/app_components.dart';
import 'about_markdown.dart';

/// 「附加页面」：常见问题与免责声明以 Tab 呈现。
///
/// 只供阅读，不包含确认/取消等操作按钮。
class ExtraPagesPage extends StatelessWidget {
  const ExtraPagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: '附加页面',
      child: AppPageBody(
        child: FTabs(
          expands: true,
          // 只允许点击切换 Tab，不支持左右滑动（保留切换动画）。
          contentPhysics: const NeverScrollableScrollPhysics(),
          children: [
            FTabEntry(
              label: const Text('常见问题'),
              child: AppPageListView(
                safeArea: false,
                showScrollbar: true,
                children: const [AboutMarkdown(asset: 'assets/about/faq.md')],
              ),
            ),
            FTabEntry(
              label: const Text('免责声明'),
              child: AppPageListView(
                safeArea: false,
                showScrollbar: true,
                children: const [
                  AboutMarkdown(asset: 'assets/about/disclaimer.md'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
