// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:upgradelink_api_dart/upgradelink_api_dart.dart';
import 'package:upgradelink_api_dart/src/models/config.dart';
import 'package:upgradelink_api_dart/src/models/url_upgrade.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/upgrade_config.dart';
import '../models/update_info.dart';

class UpdateCheckResult {
  final bool hasUpdate;
  final UpdateInfo? updateInfo;
  final String? message;

  const UpdateCheckResult({
    required this.hasUpdate,
    this.updateInfo,
    this.message,
  });
}

class UpdateException implements Exception {
  final String message;

  const UpdateException(this.message);

  @override
  String toString() => message;
}

enum UpdateDownloadStage {
  preparing,
  downloading,
  installing,
}

class UpdateDownloadProgress {
  final UpdateDownloadStage stage;
  final int receivedBytes;
  final int totalBytes;
  final double bytesPerSecond;
  final String? message;

  const UpdateDownloadProgress({
    required this.stage,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.bytesPerSecond = 0,
    this.message,
  });

  double? get progress {
    if (totalBytes <= 0) return null;
    return receivedBytes / totalBytes;
  }
}

class UpdateService {
  UpdateService._();

  static const _channel = MethodChannel('live.xuda.xzitpocket/app_bridge');
  static final Dio _downloadClient = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 10),
      followRedirects: true,
      maxRedirects: 5,
    ),
  );

  static Future<UpdateCheckResult> checkForUpdate() async {
    if (!UpgradeConfig.isConfigured) {
      throw const UpdateException('升级服务尚未配置');
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final versionCode = int.tryParse(packageInfo.buildNumber);
    if (versionCode == null) {
      throw UpdateException('当前应用构建号无效: ${packageInfo.buildNumber}');
    }

    final client = Client(
      config: Config(
        accessKey: UpgradeConfig.accessKey,
        secretKey: UpgradeConfig.secretKey,
        protocol: UpgradeConfig.protocol,
        endpoint: UpgradeConfig.endpoint,
      ),
    );

    final response = await client.getUrlUpgrade(
      UrlUpgradeRequest(
        urlKey: UpgradeConfig.urlKey,
        versionCode: versionCode,
        appointVersionCode: 0,
        devModelKey: UpgradeConfig.devModelKey,
        devKey: UpgradeConfig.devKey,
      ),
    );

    final data = response.data;
    if (data != null) {
      if (data.versionCode <= versionCode) {
        return const UpdateCheckResult(hasUpdate: false, message: '当前已是最新版本');
      }

      return UpdateCheckResult(
        hasUpdate: true,
        updateInfo: UpdateInfo(
          versionName: data.versionName,
          versionCode: data.versionCode,
          downloadUrl: data.urlPath,
          releaseNotes: data.promptUpgradeContent,
          upgradeType: data.upgradeType,
        ),
      );
    }

    if (response.code == 0) {
      return UpdateCheckResult(
        hasUpdate: false,
        message: response.msg.isEmpty ? '当前已是最新版本' : response.msg,
      );
    }

    throw UpdateException(
      response.msg.isEmpty ? '获取升级信息失败' : response.msg,
    );
  }

  static Future<void> openUpdateLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw const UpdateException('更新链接无效');
    }

    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!success) {
      throw const UpdateException('无法打开更新链接');
    }
  }

  static Future<void> downloadAndInstallUpdate(
    UpdateInfo updateInfo, {
    required void Function(UpdateDownloadProgress progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    if (!Platform.isAndroid) {
      await openUpdateLink(updateInfo.downloadUrl);
      return;
    }

    onProgress(
      const UpdateDownloadProgress(
        stage: UpdateDownloadStage.preparing,
        message: '准备下载更新包',
      ),
    );

    final targetFile = await _resolveTargetApkFile(updateInfo);

    if (!await _isReusableApk(targetFile)) {
      await _downloadApk(
        updateInfo,
        targetFile,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } else {
      final cachedSize = await targetFile.length();
      onProgress(
        UpdateDownloadProgress(
          stage: UpdateDownloadStage.downloading,
          receivedBytes: cachedSize,
          totalBytes: cachedSize,
          bytesPerSecond: 0,
          message: '已使用本地已下载的更新包',
        ),
      );
    }

    final finalSize = await targetFile.length();
    onProgress(
      UpdateDownloadProgress(
        stage: UpdateDownloadStage.installing,
        receivedBytes: finalSize,
        totalBytes: finalSize,
        message: '下载完成，准备安装',
      ),
    );

    if (!await _canRequestPackageInstalls()) {
      await _openInstallUnknownSourcesSettings();
      throw const UpdateException('请允许本应用安装未知应用后重试');
    }

    await _installApk(targetFile.path);
  }

  static Future<void> _downloadApk(
    UpdateInfo updateInfo,
    File targetFile, {
    required void Function(UpdateDownloadProgress progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await targetFile.parent.create(recursive: true);

      final stopWatch = Stopwatch()..start();
      await _downloadClient.download(
        updateInfo.downloadUrl,
        targetFile.path,
        deleteOnError: true,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          final normalizedTotal = total > 0 ? total : 0;
          final elapsedMs = stopWatch.elapsedMilliseconds;
          final speed = elapsedMs > 0 ? received * 1000 / elapsedMs : 0.0;
          onProgress(
            UpdateDownloadProgress(
              stage: UpdateDownloadStage.downloading,
              receivedBytes: received,
              totalBytes: normalizedTotal,
              bytesPerSecond: speed,
              message: '正在下载更新包',
            ),
          );
        },
      );

      final fileSize = await targetFile.length();
      if (fileSize <= 0) {
        throw const UpdateException('下载的更新包为空');
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        if (await targetFile.exists()) await targetFile.delete();
        throw const UpdateException('已取消下载');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw const UpdateException('下载更新超时，请稍后重试');
      }
      throw UpdateException('下载更新失败: ${e.message ?? '网络请求异常'}');
    } on FileSystemException catch (e) {
      throw UpdateException('保存更新包失败: ${e.message}');
    }
  }

  static Future<File> _resolveTargetApkFile(UpdateInfo updateInfo) async {
    final cacheDir = await getTemporaryDirectory();
    final updatesDir = Directory(path.join(cacheDir.path, 'updates'));
    final fileName = 'xzitpocket-update-${updateInfo.versionCode}.apk';
    return File(path.join(updatesDir.path, fileName));
  }

  static Future<bool> _isReusableApk(File file) async {
    if (!await file.exists()) return false;

    final length = await file.length();
    if (length <= 0) {
      await file.delete();
      return false;
    }
    return true;
  }

  static Future<bool> canInstallPackages() async {
    try {
      return await _channel.invokeMethod<bool>('canRequestPackageInstalls') ??
          true;
    } on PlatformException catch (e) {
      throw UpdateException(e.message ?? '无法检查安装权限');
    }
  }

  static Future<void> requestInstallPermission() async {
    try {
      await _channel.invokeMethod<void>('openInstallUnknownSourcesSettings');
    } on PlatformException catch (e) {
      throw UpdateException(e.message ?? '无法打开安装权限设置');
    }
  }

  static Future<bool> _canRequestPackageInstalls() => canInstallPackages();

  static Future<void> _openInstallUnknownSourcesSettings() =>
      requestInstallPermission();

  static Future<void> _installApk(String filePath) async {
    try {
      await _channel.invokeMethod<void>('installApk', {'filePath': filePath});
    } on PlatformException catch (e) {
      throw UpdateException(e.message ?? '无法启动安装器');
    }
  }
}
