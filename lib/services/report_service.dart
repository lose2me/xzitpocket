import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/upgrade_config.dart';
import 'debug_log_service.dart';

class ReportService {
  ReportService._();

  static Future<void> reportAppStart() =>
      _report('app_start', {'launchTime': _rfc3339Now()});

  static Future<void> reportUpgradeDownload(
    int downloadVersionCode,
    int code,
  ) =>
      _report('app_upgrade_download', {
        'downloadVersionCode': downloadVersionCode,
        'code': code,
      });

  static Future<void> reportUpgradeUpgrade(
    int upgradeVersionCode,
    int code,
  ) =>
      _report('app_upgrade_upgrade', {
        'upgradeVersionCode': upgradeVersionCode,
        'code': code,
      });

  static Future<void> _report(
    String eventType,
    Map<String, dynamic> extra,
  ) async {
    if (!UpgradeConfig.isConfigured) return;
    try {
      final device = await _collectDeviceInfo();
      final pkg = await PackageInfo.fromPlatform();

      await _post({
        'eventType': eventType,
        'timestamp': _rfc3339Now(),
        'appKey': UpgradeConfig.urlKey,
        'eventData': {
          'versionCode': int.tryParse(pkg.buildNumber) ?? 0,
          ...device,
          ...extra,
        },
      });
      DebugLogService.instance
          .log(DebugLogCategory.action, '事件上报', '$eventType 成功');
    } catch (e) {
      DebugLogService.instance
          .log(DebugLogCategory.error, '事件上报失败', '$eventType: $e');
    }
  }

  // ── HTTP ──

  static Future<void> _post(Map<String, dynamic> payload) async {
    final body = jsonEncode(payload);
    final timestamp = _rfc3339Now();
    final nonce = _generateNonce();
    const path = '/v1/app/report';

    final signature = _generateSignature(
      body,
      nonce,
      UpgradeConfig.secretKey,
      timestamp,
      path,
    );

    final uri = Uri(
      scheme: UpgradeConfig.protocol,
      host: UpgradeConfig.endpoint,
      path: path,
    );

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set('content-type', 'application/json');
      request.headers.set('X-Timestamp', timestamp);
      request.headers.set('X-Nonce', nonce);
      request.headers.set('X-AccessKey', UpgradeConfig.accessKey);
      request.headers.set('X-Signature', signature);
      request.write(body);
      final response = await request.close();
      await response.drain<void>();
    } finally {
      client.close();
    }
  }

  // ── Signing (mirrors upgradelink_api_dart) ──

  static String _rfc3339Now() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hh = offset.inHours.abs().toString().padLeft(2, '0');
    final mm = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '${now.year}-${_p2(now.month)}-${_p2(now.day)}'
        'T${_p2(now.hour)}:${_p2(now.minute)}:${_p2(now.second)}'
        '$sign$hh:$mm';
  }

  static String _p2(int n) => n.toString().padLeft(2, '0');

  static String _generateNonce() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(16, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  static String _generateSignature(
    String body,
    String nonce,
    String secretKey,
    String timestamp,
    String uri,
  ) {
    final parts = <String>[];
    if (body.isNotEmpty) parts.add('body=$body');
    parts.addAll([
      'nonce=$nonce',
      'secretKey=$secretKey',
      'timestamp=$timestamp',
      'url=$uri',
    ]);
    return md5.convert(utf8.encode(parts.join('&'))).toString();
  }

  // ── Device info ──

  static Future<Map<String, dynamic>> _collectDeviceInfo() async {
    final info = <String, dynamic>{};

    if (UpgradeConfig.devModelKey.isNotEmpty) {
      info['devModelKey'] = UpgradeConfig.devModelKey;
    }
    if (UpgradeConfig.devKey.isNotEmpty) {
      info['devKey'] = UpgradeConfig.devKey;
    }

    try {
      if (Platform.isAndroid) {
        final android = await DeviceInfoPlugin().androidInfo;
        info['target'] = 'android';
        info.putIfAbsent('devModelKey', () => android.model);
        info.putIfAbsent('devKey', () => android.id);
        final abis = android.supportedAbis;
        if (abis.isNotEmpty) info['arch'] = abis.first;
      } else if (Platform.isIOS) {
        final ios = await DeviceInfoPlugin().iosInfo;
        info['target'] = 'ios';
        info.putIfAbsent('devModelKey', () => ios.model);
        info.putIfAbsent('devKey', () => ios.identifierForVendor ?? '');
        info['arch'] = 'arm64';
      }
    } catch (_) {}

    return info;
  }
}
