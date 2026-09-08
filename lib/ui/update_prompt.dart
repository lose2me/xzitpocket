import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../services/control_service.dart';
import '../services/update_service.dart';
import 'app_tokens.dart';

Future<void> showAppUpdatePrompt({
  required BuildContext context,
  required ControlRelease release,
}) => showFDialog<void>(
  context: context,
  builder: (context, style, animation) => FDialog(
    animation: animation,
    builder: (context, style) => _AppUpdatePrompt(release: release),
  ),
);

class _AppUpdatePrompt extends StatefulWidget {
  final ControlRelease release;

  const _AppUpdatePrompt({required this.release});

  @override
  State<_AppUpdatePrompt> createState() => _AppUpdatePromptState();
}

class _AppUpdatePromptState extends State<_AppUpdatePrompt> {
  UpdateDownloadProgress? _progress;
  CancelToken? _cancelToken;
  String? _error;
  bool _downloading = false;

  @override
  void dispose() {
    _cancelToken?.cancel('update prompt closed');
    super.dispose();
  }

  Future<void> _download() async {
    if (_downloading) return;
    final cancelToken = CancelToken();
    setState(() {
      _downloading = true;
      _cancelToken = cancelToken;
      _error = null;
      _progress = const UpdateDownloadProgress(
        stage: UpdateDownloadStage.preparing,
        message: '准备下载更新包',
      );
    });
    try {
      await UpdateService.downloadAndInstall(
        widget.release,
        cancelToken: cancelToken,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (mounted) Navigator.pop(context);
    } on UpdateException catch (error) {
      if (mounted && error.message != '已取消下载') {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) setState(() => _error = '下载更新失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _cancelToken = null;
        });
      }
    }
  }

  void _dismiss() {
    _cancelToken?.cancel('user cancelled');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Text(
              '发现新版本',
              textAlign: TextAlign.center,
              style: context.theme.typography.pageTitle,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '版本 ${widget.release.latestVersion} 已发布，是否立即下载并安装？',
            style: context.theme.typography.bodySmall.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
          if (_downloading || progress != null) ...[
            const SizedBox(height: AppSpacing.lg),
            if (progress?.progress case final value?)
              FDeterminateProgress(value: value)
            else
              const FProgress(),
            if (progress != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(progress.message, style: context.theme.typography.bodySmall),
              if (progress.totalBytes > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _progressLine(progress),
                  style: context.theme.typography.caption.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
              ],
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: context.theme.typography.bodySmall.copyWith(
                color: context.theme.colors.destructive,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FButton(
                variant: FButtonVariant.ghost,
                size: FButtonSizeVariant.sm,
                mainAxisSize: MainAxisSize.min,
                onPress: _dismiss,
                child: Text(_downloading ? '取消下载' : '稍后'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FButton(
                size: FButtonSizeVariant.sm,
                mainAxisSize: MainAxisSize.min,
                onPress: _downloading ? null : _download,
                child: Text(_error == null ? '立即更新' : '重试'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _progressLine(UpdateDownloadProgress progress) {
    final received = _formatBytes(progress.receivedBytes);
    final total = _formatBytes(progress.totalBytes);
    final percent = ((progress.progress ?? 0) * 100).toStringAsFixed(1);
    final speed = progress.stage == UpdateDownloadStage.downloading
        ? ' · ${_formatBytes(progress.bytesPerSecond.round())}/s'
        : '';
    return '$received / $total ($percent%)$speed';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
  }
}
