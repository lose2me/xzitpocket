import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../ui/app_components.dart';

/// Renders a downloaded PDF inside the app instead of handing it to an
/// external viewer.
class PdfViewerPage extends StatelessWidget {
  final String title;
  final String path;

  const PdfViewerPage({super.key, required this.title, required this.path});

  @override
  Widget build(BuildContext context) {
    if (!File(path).existsSync()) {
      return AppPage(
        title: title,
        child: AppStateView(
          icon: FLucideIcons.fileX,
          title: '文件已不存在',
          description: '重新下载后再试',
        ),
      );
    }
    return AppPage(
      title: title,
      child: ColoredBox(
        color: context.theme.colors.background,
        child: PdfViewer.file(
          path,
          params: const PdfViewerParams(margin: 8),
        ),
      ),
    );
  }
}
