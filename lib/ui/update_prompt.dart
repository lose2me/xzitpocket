import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../services/control_service.dart';
import '../services/update_service.dart';
import 'app_components.dart';
import 'app_markdown.dart';

/// 版本更新二级页面：上方是下载模块，下方是更新日志模块。
/// 由「我的 → 发现新版本」进入；不自动弹出，也没有「我知道了」按钮。
class AppUpdatePage extends StatefulWidget {
  final ControlRelease release;

  /// 当前已安装版本，用于在下载模块上方显示「当前 → 最新」。
  final String currentVersion;

  const AppUpdatePage({
    super.key,
    required this.release,
    this.currentVersion = '',
  });

  @override
  State<AppUpdatePage> createState() => _AppUpdatePageState();
}

class _AppUpdatePageState extends State<AppUpdatePage> {
  UpdateDownloadProgress? _progress;
  CancelToken? _cancelToken;
  String? _error;
  bool _downloading = false;

  @override
  void dispose() {
    _cancelToken?.cancel('update page closed');
    super.dispose();
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _error = null);
    // 先确认「安装未知应用」权限；未授权时打开系统设置，不展开下载界面，
    // 授权后回来再次点击即开始下载。
    if (!await UpdateService.ensureInstallPermission()) {
      if (mounted) {
        setState(() => _error = '请允许本应用安装未知应用后重试');
      }
      return;
    }
    if (!mounted) return;
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
      if (mounted) setState(() => _progress = null);
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

  void _cancelDownload() {
    _cancelToken?.cancel('user cancelled');
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final release = widget.release;
    final changelog = release.changelog.trim();
    final progress = _progress;
    return AppPage(
      title: '发现新版本',
      child: AppPageListView(
        maxWidth: AppLayout.resultMaxWidth,
        topPadding: AppSpacing.lg,
        bottomPadding: AppSpacing.xxl,
        showScrollbar: true,
        children: [
          // ── 下载模块：仅一个「下载并安装」按钮，拿到安装权限后才展开进度 ──
          if (_versionLine case final versionLine?) ...[
            Text(
              versionLine,
              textAlign: TextAlign.center,
              style: theme.typography.bodySmall.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              Expanded(
                child: FButton(
                  onPress: _downloading ? null : _download,
                  prefix: _downloading
                      ? const FCircularProgress(
                          size: FCircularProgressSizeVariant.sm,
                        )
                      : const Icon(FLucideIcons.download),
                  child: Text(_downloading ? '下载中…' : '下载并安装'),
                ),
              ),
              if (_downloading) ...[
                const SizedBox(width: AppSpacing.sm),
                FButton(
                  variant: FButtonVariant.outline,
                  mainAxisSize: MainAxisSize.min,
                  onPress: _cancelDownload,
                  child: const Text('取消'),
                ),
              ],
            ],
          ),
          if (_downloading || progress != null) ...[
            const SizedBox(height: AppSpacing.md),
            if (progress?.progress case final value?)
              FDeterminateProgress(value: value)
            else
              const FProgress(),
            if (progress != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(progress.message, style: theme.typography.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _progressLine(progress),
                style: theme.typography.caption.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.typography.bodySmall.copyWith(
                color: theme.colors.destructive,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          // ── 更新日志模块 ──
          Text('更新日志', style: theme.typography.tileTitle),
          const SizedBox(height: AppSpacing.md),
          if (changelog.isEmpty)
            Text(
              '暂无更新日志',
              style: theme.typography.bodySmall.copyWith(
                color: theme.colors.mutedForeground,
              ),
            )
          else
            AppMarkdown(data: changelog),
        ],
      ),
    );
  }

  String? get _versionLine {
    final current = widget.currentVersion.trim();
    return current.isEmpty
        ? null
        : '$current → ${widget.release.latestVersion}';
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
