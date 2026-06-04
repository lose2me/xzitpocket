// ignore_for_file: implementation_imports

import 'package:package_info_plus/package_info_plus.dart';
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

class UpdateService {
  UpdateService._();

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

    if (response.code != 0) {
      throw UpdateException(
        response.msg.isEmpty ? '获取升级信息失败' : response.msg,
      );
    }

    final data = response.data;
    if (data == null) {
      return UpdateCheckResult(
        hasUpdate: false,
        message: response.msg.isEmpty ? '当前已是最新版本' : response.msg,
      );
    }

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
}
