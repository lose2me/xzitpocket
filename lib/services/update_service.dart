import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ui/app_components.dart';
import 'control_service.dart';

enum UpdateDownloadStage { preparing, downloading, installing }

class UpdateDownloadProgress {
  final UpdateDownloadStage stage;
  final int receivedBytes;
  final int totalBytes;
  final double bytesPerSecond;
  final String message;

  const UpdateDownloadProgress({
    required this.stage,
    required this.message,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.bytesPerSecond = 0,
  });

  double? get progress =>
      totalBytes <= 0 ? null : (receivedBytes / totalBytes).clamp(0.0, 1.0);
}

class UpdateException implements Exception {
  final String message;

  const UpdateException(this.message);

  @override
  String toString() => message;
}

class UpdateService {
  UpdateService._();

  static const _channel = MethodChannel('live.xuda.xzitpocket/app_bridge');
  static final _downloadClient = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 10),
      followRedirects: true,
      maxRedirects: 5,
    ),
  );

  static Future<void> downloadAndInstall(
    ControlRelease release, {
    required ValueChanged<UpdateDownloadProgress> onProgress,
    CancelToken? cancelToken,
  }) async {
    if (!Platform.isAndroid) {
      final opened = await launchUrl(
        release.downloadUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw const UpdateException('无法打开更新地址');
      return;
    }

    onProgress(
      const UpdateDownloadProgress(
        stage: UpdateDownloadStage.preparing,
        message: '准备下载更新包',
      ),
    );
    final target = await _targetFile(release.latestVersion);
    if (await target.exists()) await target.delete();
    await target.parent.create(recursive: true);

    try {
      final stopwatch = Stopwatch()..start();
      await _downloadClient.download(
        release.downloadUrl.toString(),
        target.path,
        cancelToken: cancelToken,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          final elapsed = stopwatch.elapsedMilliseconds;
          onProgress(
            UpdateDownloadProgress(
              stage: UpdateDownloadStage.downloading,
              receivedBytes: received,
              totalBytes: total > 0 ? total : 0,
              bytesPerSecond: elapsed > 0 ? received * 1000 / elapsed : 0,
              message: '正在下载更新包',
            ),
          );
        },
      );
      if (!await target.exists() || await target.length() <= 0) {
        throw const UpdateException('下载的更新包为空');
      }
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const UpdateException('已取消下载');
      }
      throw UpdateException(
        error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.receiveTimeout ||
                error.type == DioExceptionType.sendTimeout
            ? '下载更新超时，请稍后重试'
            : '下载更新失败，请检查网络后重试',
      );
    } on FileSystemException catch (error) {
      throw UpdateException('保存更新包失败：${error.message}');
    }

    final size = await target.length();
    onProgress(
      UpdateDownloadProgress(
        stage: UpdateDownloadStage.installing,
        receivedBytes: size,
        totalBytes: size,
        message: '下载完成，准备安装',
      ),
    );
    if (!await _canRequestPackageInstalls()) {
      await _channel.invokeMethod<void>('openInstallUnknownSourcesSettings');
      throw const UpdateException('请允许本应用安装未知应用后重试');
    }
    try {
      await _channel.invokeMethod<void>('installApk', {
        'filePath': target.path,
      });
    } on PlatformException catch (error) {
      throw UpdateException(error.message ?? '无法启动系统安装器');
    }
  }

  static Future<File> _targetFile(String version) async {
    final directory = await getTemporaryDirectory();
    final safeVersion = version.replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_');
    return File(
      p.join(directory.path, 'updates', 'xzitpocket-$safeVersion.apk'),
    );
  }

  static Future<bool> _canRequestPackageInstalls() async {
    try {
      return await _channel.invokeMethod<bool>('canRequestPackageInstalls') ??
          true;
    } on PlatformException catch (error) {
      throw UpdateException(error.message ?? '无法检查安装权限');
    }
  }
}

Future<void> showAppUpdatePrompt(
  BuildContext context,
  ControlRelease release,
) async {
  final confirmed = await showFDialog<bool>(
    context: context,
    useSafeArea: true,
    builder: (context, style, animation) => FDialog(
      animation: animation,
      builder: (context, style) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Text(
                '发现新版本 ${release.latestVersion}',
                textAlign: TextAlign.center,
                style: context.theme.typography.pageTitle,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '新版本已经发布，可直接在应用内下载并安装。',
              style: context.theme.typography.bodySmall.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FButton(
                  variant: FButtonVariant.ghost,
                  size: FButtonSizeVariant.sm,
                  mainAxisSize: MainAxisSize.min,
                  onPress: () => Navigator.pop(context, false),
                  child: const Text('稍后'),
                ),
                const SizedBox(width: AppSpacing.sm),
                FButton(
                  variant: FButtonVariant.primary,
                  size: FButtonSizeVariant.sm,
                  mainAxisSize: MainAxisSize.min,
                  onPress: () => Navigator.pop(context, true),
                  prefix: const Icon(FLucideIcons.download),
                  child: const Text('立即更新'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await showFDialog<void>(
    context: context,
    barrierDismissible: false,
    useSafeArea: true,
    builder: (context, style, animation) => FDialog(
      animation: animation,
      builder: (context, style) => _UpdateDownloadDialog(release: release),
    ),
  );
}

class _UpdateDownloadDialog extends StatefulWidget {
  final ControlRelease release;

  const _UpdateDownloadDialog({required this.release});

  @override
  State<_UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends State<_UpdateDownloadDialog> {
  UpdateDownloadProgress _progress = const UpdateDownloadProgress(
    stage: UpdateDownloadStage.preparing,
    message: '准备下载更新包',
  );
  CancelToken? _cancelToken;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final token = CancelToken();
    setState(() {
      _cancelToken = token;
      _error = null;
      _progress = const UpdateDownloadProgress(
        stage: UpdateDownloadStage.preparing,
        message: '准备下载更新包',
      );
    });
    try {
      await UpdateService.downloadAndInstall(
        widget.release,
        cancelToken: token,
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
    }
  }

  void _cancel() {
    _cancelToken?.cancel();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final determinate = _progress.progress;
    return PopScope(
      canPop: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Text(
                _error == null ? _title : '更新失败',
                textAlign: TextAlign.center,
                style: context.theme.typography.pageTitle,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_error != null)
              Text(_error!, style: context.theme.typography.bodySmall)
            else ...[
              if (determinate == null)
                const FProgress()
              else
                FDeterminateProgress(value: determinate),
              const SizedBox(height: AppSpacing.md),
              Text(
                _progress.message,
                style: context.theme.typography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _progressLine,
                style: context.theme.typography.caption.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_error == null)
                  FButton(
                    variant: FButtonVariant.ghost,
                    size: FButtonSizeVariant.sm,
                    mainAxisSize: MainAxisSize.min,
                    onPress: _cancel,
                    child: const Text('取消'),
                  )
                else ...[
                  FButton(
                    variant: FButtonVariant.ghost,
                    size: FButtonSizeVariant.sm,
                    mainAxisSize: MainAxisSize.min,
                    onPress: () => Navigator.pop(context),
                    child: const Text('关闭'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FButton(
                    variant: FButtonVariant.primary,
                    size: FButtonSizeVariant.sm,
                    mainAxisSize: MainAxisSize.min,
                    onPress: _start,
                    prefix: const Icon(FLucideIcons.refreshCw),
                    child: const Text('重试'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _title => switch (_progress.stage) {
    UpdateDownloadStage.preparing => '准备更新',
    UpdateDownloadStage.downloading => '正在下载',
    UpdateDownloadStage.installing => '准备安装',
  };

  String get _progressLine {
    final received = _formatBytes(_progress.receivedBytes);
    if (_progress.totalBytes <= 0) return received;
    final total = _formatBytes(_progress.totalBytes);
    final percent = ((_progress.progress ?? 0) * 100).toStringAsFixed(1);
    final speed = _progress.stage == UpdateDownloadStage.downloading
        ? ' · ${_formatBytes(_progress.bytesPerSecond.round())}/s'
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
