import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/app_components.dart';
import '../../ui/app_markdown.dart';

/// Static FAQ page. Deliberately has no in-page action buttons; navigation
/// back happens through the AppBar back action or the system back gesture.
class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  static const _contentAsset = 'assets/about/faq.md';
  String? _content;

  @override
  void initState() {
    super.initState();
    unawaited(_loadContent());
  }

  Future<void> _loadContent() async {
    final content = await rootBundle.loadString(_contentAsset);
    if (mounted) setState(() => _content = content);
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    return AppPage(
      title: '常见问题',
      child: AppPageListView(
        showScrollbar: true,
        children: [if (content != null) AppMarkdown(data: content)],
      ),
    );
  }
}
