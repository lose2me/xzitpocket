import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

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

    // Android checks this before any network work. If permission is missing,
    // the system settings page is opened and the caller can retry afterwards.
    if (!await _ensurePackageInstallPermission()) {
      throw const UpdateException('请允许本应用安装未知应用后重试');
    }

    onProgress(
      const UpdateDownloadProgress(
        stage: UpdateDownloadStage.preparing,
        message: '检查本地更新包',
      ),
    );
    final target = await _targetFile(release.latestVersion);
    final marker = _completionMarker(target);
    await target.parent.create(recursive: true);

    if (await _isReusableApk(target, marker)) {
      final size = await target.length();
      onProgress(
        UpdateDownloadProgress(
          stage: UpdateDownloadStage.downloading,
          receivedBytes: size,
          totalBytes: size,
          message: '使用已下载的更新包',
        ),
      );
    } else {
      if (await target.exists()) await target.delete();
      if (await marker.exists()) await marker.delete();
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
        if (!await _isUsableApk(target)) {
          throw const UpdateException('下载的更新包无效');
        }
        await marker.writeAsString('complete', flush: true);
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
    try {
      await _channel.invokeMethod<void>('installApk', {
        'filePath': target.path,
      });
    } on PlatformException catch (error) {
      throw UpdateException(error.message ?? '无法启动系统安装器');
    }
  }

  static Future<File> _targetFile(String version) async {
    final directory = await getApplicationSupportDirectory();
    final safeVersion = version.replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_');
    return File(
      p.join(directory.path, 'updates', 'xzitpocket-$safeVersion.apk'),
    );
  }

  static File _completionMarker(File target) => File('${target.path}.ready');

  static Future<bool> _canRequestPackageInstalls() async {
    try {
      return await _channel.invokeMethod<bool>('canRequestPackageInstalls') ??
          true;
    } on PlatformException catch (error) {
      throw UpdateException(error.message ?? '无法检查安装权限');
    }
  }

  static Future<bool> _ensurePackageInstallPermission() async {
    if (await _canRequestPackageInstalls()) return true;
    try {
      await _channel.invokeMethod<void>('openInstallUnknownSourcesSettings');
    } on PlatformException catch (error) {
      throw UpdateException(error.message ?? '无法打开安装权限设置');
    }
    return false;
  }

  static Future<bool> _isUsableApk(File file) async {
    if (!await file.exists() || await file.length() < 4) return false;
    try {
      final header = await file.openRead(0, 4).first;
      return header.length == 4 &&
          header[0] == 0x50 &&
          header[1] == 0x4b &&
          header[2] == 0x03 &&
          header[3] == 0x04;
    } on FileSystemException {
      return false;
    }
  }

  static Future<bool> _isReusableApk(File file, File marker) async =>
      await marker.exists() && await _isUsableApk(file);
}
