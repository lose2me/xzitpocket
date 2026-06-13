import 'dart:io';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum DebugLogCategory { network, auth, navigation, action, error, lifecycle }

class DebugLogEntry {
  final DateTime timestamp;
  final DebugLogCategory category;
  final String title;
  final String detail;

  const DebugLogEntry({
    required this.timestamp,
    required this.category,
    required this.title,
    this.detail = '',
  });

  String get categoryLabel => switch (category) {
        DebugLogCategory.network => 'NET',
        DebugLogCategory.auth => 'AUTH',
        DebugLogCategory.navigation => 'NAV',
        DebugLogCategory.action => 'ACT',
        DebugLogCategory.error => 'ERR',
        DebugLogCategory.lifecycle => 'LIFE',
      };

  String get timeLabel {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String toExportLine() {
    final buf = StringBuffer('[$timeLabel] [$categoryLabel] $title');
    if (detail.isNotEmpty) buf.write('  $detail');
    return buf.toString();
  }
}

class DebugLogService {
  DebugLogService._();
  static final instance = DebugLogService._();

  static const _maxEntries = 500;

  bool enabled = false;
  final List<DebugLogEntry> entries = [];
  VoidCallback? onUpdate;
  String _envSnapshot = '';
  int _reqId = 0;

  FlutterExceptionHandler? _originalFlutterError;
  ErrorCallback? _originalPlatformError;

  // ── Logging ──

  void log(DebugLogCategory category, String title, [String detail = '']) {
    if (!enabled) return;
    if (entries.length >= _maxEntries) {
      entries.removeRange(0, entries.length - _maxEntries + 50);
    }
    entries.add(DebugLogEntry(
      timestamp: DateTime.now(),
      category: category,
      title: title,
      detail: _redact(detail),
    ));
    onUpdate?.call();
  }

  void clear() {
    entries.clear();
    _reqId = 0;
    onUpdate?.call();
  }

  // ── Environment Snapshot ──

  Future<void> collectEnvironment() async {
    final buf = StringBuffer();

    try {
      final pkg = await PackageInfo.fromPlatform();
      buf.writeln('App: ${pkg.appName} v${pkg.version}+${pkg.buildNumber}');
    } catch (_) {}

    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        buf.writeln(
            '设备: ${info.brand} ${info.model} (${info.device})');
        buf.writeln(
            '系统: Android ${info.version.release} (SDK ${info.version.sdkInt})');
        buf.writeln(
            '安全补丁: ${info.version.securityPatch ?? 'N/A'}');
      } else if (Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        buf.writeln('设备: ${info.model} ${info.name}');
        buf.writeln('系统: iOS ${info.systemVersion}');
      }
    } catch (_) {}

    try {
      final view = PlatformDispatcher.instance.implicitView;
      if (view != null) {
        final size = view.physicalSize;
        final ratio = view.devicePixelRatio;
        buf.writeln(
            '屏幕: ${size.width.toInt()}x${size.height.toInt()} @${ratio.toStringAsFixed(1)}x');
      }
    } catch (_) {}

    try {
      final conn = await Connectivity().checkConnectivity();
      final label = conn.map((c) => c.name).join(', ');
      buf.writeln('网络: $label');
    } catch (_) {}

    buf.write('平台: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');

    _envSnapshot = buf.toString();
    log(DebugLogCategory.action, '环境信息', _envSnapshot);
  }

  // ── Error Handlers ──

  void installErrorHandlers() {
    _originalFlutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      log(
        DebugLogCategory.error,
        'Flutter 异常: ${details.exceptionAsString()}',
        details.stack?.toString() ?? '',
      );
      _originalFlutterError?.call(details);
    };

    _originalPlatformError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      log(
        DebugLogCategory.error,
        '未捕获异常: $error',
        stack.toString(),
      );
      return _originalPlatformError?.call(error, stack) ?? false;
    };
  }

  void removeErrorHandlers() {
    if (_originalFlutterError != null) {
      FlutterError.onError = _originalFlutterError;
      _originalFlutterError = null;
    }
    if (_originalPlatformError != null) {
      PlatformDispatcher.instance.onError = _originalPlatformError;
      _originalPlatformError = null;
    }
  }

  // ── Export ──

  String export() {
    if (entries.isEmpty) return '(empty)';
    final buf = StringBuffer();
    if (_envSnapshot.isNotEmpty) {
      buf.writeln('═══ 环境信息 ═══');
      buf.writeln(_envSnapshot);
      buf.writeln('═══════════════');
      buf.writeln();
    }
    final first = entries.first.timeLabel;
    final last = entries.last.timeLabel;
    buf.writeln('日志 $first ~ $last  共 ${entries.length} 条');
    buf.writeln();
    for (final e in entries) {
      buf.writeln(e.toExportLine());
    }
    return buf.toString();
  }

  // ── Dio Interceptor ──

  Interceptor get dioInterceptor => InterceptorsWrapper(
        onRequest: (options, handler) {
          final id = ++_reqId;
          options.extra['_debugReqId'] = id;
          options.extra['_debugStart'] = DateTime.now().millisecondsSinceEpoch;

          final headers = _summarizeHeaders(options.headers);
          log(
            DebugLogCategory.network,
            '#$id → ${options.method} ${_shortenUrl(options.uri.toString())}',
            headers,
          );
          handler.next(options);
        },
        onResponse: (response, handler) {
          final id = response.requestOptions.extra['_debugReqId'] ?? '?';
          final start =
              response.requestOptions.extra['_debugStart'] as int?;
          final elapsed =
              start != null ? DateTime.now().millisecondsSinceEpoch - start : 0;

          final size = _estimateSize(response);
          final detail = '${size}B  ${elapsed}ms';

          if (elapsed > 5000) {
            log(
              DebugLogCategory.error,
              '#$id ⚠ 慢请求 ${response.statusCode} ${_shortenUrl(response.requestOptions.uri.toString())}',
              detail,
            );
          } else {
            log(
              DebugLogCategory.network,
              '#$id ← ${response.statusCode} ${_shortenUrl(response.requestOptions.uri.toString())}',
              detail,
            );
          }
          handler.next(response);
        },
        onError: (error, handler) {
          final id = error.requestOptions.extra['_debugReqId'] ?? '?';
          final start = error.requestOptions.extra['_debugStart'] as int?;
          final elapsed =
              start != null ? DateTime.now().millisecondsSinceEpoch - start : 0;
          log(
            DebugLogCategory.error,
            '#$id ✗ ${error.type.name} ${_shortenUrl(error.requestOptions.uri.toString())} (${elapsed}ms)',
            error.message ?? '',
          );
          handler.next(error);
        },
      );

  // ── Redaction ──

  static final _phoneRe = RegExp(r'1[3-9]\d{9}');
  static final _idCardRe = RegExp(r'\d{17}[\dXx]');
  static final _pwdFieldRe =
      RegExp(r'(password|pwd|token|secret|authorization)\s*[=:]\s*\S+', caseSensitive: false);

  static String _redact(String input) {
    if (input.isEmpty) return input;
    var result = input;
    result = result.replaceAllMapped(_phoneRe, (m) {
      final s = m[0]!;
      return '${s.substring(0, 3)}****${s.substring(7)}';
    });
    result = result.replaceAllMapped(_idCardRe, (m) {
      final s = m[0]!;
      return '${s.substring(0, 4)}****${s.substring(s.length - 4)}';
    });
    result = result.replaceAllMapped(_pwdFieldRe, (m) {
      final full = m[0]!;
      final eqIdx = full.indexOf(RegExp(r'[=:]'));
      if (eqIdx < 0) return full;
      return '${full.substring(0, eqIdx + 1)} ***';
    });
    return result;
  }

  // ── Helpers ──

  static String _shortenUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final host = uri.host;
    final path = uri.path;
    if (uri.queryParameters.isEmpty) return '$host$path';
    return '$host$path?...';
  }

  String _summarizeHeaders(Map<String, dynamic> headers) {
    final parts = <String>[];
    final ct = headers['Content-Type'] ?? headers['content-type'];
    if (ct != null) parts.add('CT: $ct');
    final auth = headers['Authorization'] ?? headers['authorization'];
    if (auth != null) parts.add('Auth: ***');
    final cookie = headers['Cookie'] ?? headers['cookie'];
    if (cookie != null) {
      final count = cookie.toString().split(';').length;
      parts.add('Cookies: $count');
    }
    return parts.join(', ');
  }

  int _estimateSize(Response response) {
    final data = response.data;
    if (data == null) return 0;
    if (data is String) return data.length;
    if (data is List<int>) return data.length;
    return data.toString().length;
  }
}
