import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../services/resource_download_service.dart';
import '../../ui/app_components.dart';
import '../../utils/snackbar_helper.dart';

/// Renders a downloaded PDF inside the app instead of handing it to an
/// external viewer. The header action still allows opening it elsewhere.
class PdfViewerPage extends StatelessWidget {
  final String title;
  final String path;
  final DownloadedResource record;
  final String format;

  const PdfViewerPage({
    super.key,
    required this.title,
    required this.path,
    required this.record,
    this.format = 'pdf',
  });

  Future<void> _openExternally(BuildContext context) async {
    try {
      await ResourceDownloadService.instance.open(record, format: format);
    } catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, '没有可以打开该文件的应用', severity: ToastSeverity.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      AppIconButton(
        icon: FLucideIcons.externalLink,
        tooltip: '用其他应用打开',
        onPress: () => unawaited(_openExternally(context)),
      ),
    ];
    if (!File(path).existsSync()) {
      return AppPage(
        title: title,
        actions: actions,
        child: AppStateView(
          icon: FLucideIcons.fileX,
          title: '文件已不存在',
          description: '重新下载后再试',
        ),
      );
    }
    return AppPage(
      title: title,
      actions: actions,
      child: ColoredBox(
        color: context.theme.colors.background,
        child: PdfViewer.file(path, params: const PdfViewerParams(margin: 8)),
      ),
    );
  }
}
