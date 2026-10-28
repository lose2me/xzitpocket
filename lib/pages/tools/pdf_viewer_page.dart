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
class PdfViewerPage extends StatefulWidget {
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

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  final _controller = PdfViewerController();

  Future<void> _openExternally() async {
    try {
      await ResourceDownloadService.instance.open(
        widget.record,
        format: widget.format,
        chooser: true,
      );
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, '没有可以打开该文件的应用', severity: ToastSeverity.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final actions = [
      AppIconButton(
        icon: FLucideIcons.externalLink,
        tooltip: '用其他应用打开',
        onPress: () => unawaited(_openExternally()),
      ),
    ];
    if (!File(widget.path).existsSync()) {
      return AppPage(
        title: widget.title,
        actions: actions,
        child: AppStateView(
          icon: FLucideIcons.fileX,
          title: '文件已不存在',
          description: '重新下载后再试',
        ),
      );
    }
    return AppPage(
      title: widget.title,
      actions: actions,
      child: ColoredBox(
        color: theme.colors.background,
        child: PdfViewer.file(
          widget.path,
          controller: _controller,
          params: PdfViewerParams(
            margin: 8,
            // 页面阴影和批注都要额外绘制，去掉后滚动更跟手。
            pageDropShadow: null,
            annotationRenderingMode: PdfAnnotationRenderingMode.none,
            // 默认 0.0000135 的惯性很短，一划就停；调到接近列表的滑行距离。
            interactionEndFrictionCoefficient: 0.02,
            viewerOverlayBuilder: (context, size, handleLinkTap) => [
              // pdfrx 不自带滚动条，这里补一个可拖动的页码滚动条。
              PdfViewerScrollThumb(
                controller: _controller,
                orientation: ScrollbarOrientation.right,
                margin: 4,
                thumbSize: const Size(18, 44),
                thumbBuilder: (context, thumbSize, pageNumber, controller) =>
                    Container(
                      width: thumbSize.width,
                      height: thumbSize.height,
                      decoration: BoxDecoration(
                        color: theme.colors.primary.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: Text(
                          '${pageNumber ?? ''}',
                          style: theme.typography.caption.copyWith(
                            color: theme.colors.primaryForeground,
                          ),
                        ),
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
