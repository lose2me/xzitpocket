import 'package:material_ui/material_ui.dart';

import '../../ui/app_components.dart';
import 'about_markdown.dart';

/// Static FAQ page. Deliberately has no in-page action buttons; navigation
/// back happens through the AppBar back action or the system back gesture.
class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: '常见问题',
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        showScrollbar: true,
        children: const [AboutMarkdown(asset: 'assets/about/faq.md')],
      ),
    );
  }
}
