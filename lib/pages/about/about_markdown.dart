import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../ui/app_markdown.dart';

/// Loads a bundled markdown document used by the about pages.
///
/// Renders nothing until the asset is loaded so it can sit directly inside an
/// [AppPageListView] or a tab without owning the scroll view.
class AboutMarkdown extends StatefulWidget {
  final String asset;

  const AboutMarkdown({super.key, required this.asset});

  @override
  State<AboutMarkdown> createState() => _AboutMarkdownState();
}

class _AboutMarkdownState extends State<AboutMarkdown> {
  String? _content;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final content = await rootBundle.loadString(widget.asset);
    if (mounted) setState(() => _content = content);
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    if (content == null) return const SizedBox.shrink();
    return AppMarkdown(data: content);
  }
}
