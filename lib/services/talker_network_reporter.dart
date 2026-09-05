import 'dart:async';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'control_crypto.dart';
import 'control_service.dart';
import 'talker.dart';

class TalkerNetworkReporter {
  TalkerNetworkReporter._();

  static final instance = TalkerNetworkReporter._();

  StreamSubscription<TalkerData>? _subscription;
  PackageInfo? _packageInfo;
  final List<TalkerData> _pending = [];
  bool _sending = false;
  bool _reporting = false;

  void initialize() {
    _subscription ??= talker.stream.listen(_handle);
  }

  void _handle(TalkerData data) {
    if (!talker.settings.enabled || _reporting || !_isError(data)) return;
    if (_pending.length >= 50) _pending.removeAt(0);
    _pending.add(data);
    unawaited(_drain());
  }

  bool _isError(TalkerData data) {
    return data is TalkerError ||
        data is TalkerException ||
        data.logLevel == LogLevel.error ||
        data.logLevel == LogLevel.critical;
  }

  Future<void> _drain() async {
    if (_sending) return;
    _sending = true;
    try {
      while (_pending.isNotEmpty) {
        final data = _pending.removeAt(0);
        _reporting = true;
        try {
          final info = _packageInfo ??= await PackageInfo.fromPlatform();
          await ControlService.instance.reportErrorLog(
            eventId: controlRandomToken(18),
            occurredAt: data.time,
            title: _sanitize(data.title ?? data.key ?? 'error', 128),
            message: _sanitize(data.message ?? '', 4096),
            error: _sanitize(
              data.error?.toString() ?? data.exception?.toString() ?? '',
              4096,
            ),
            stackTrace: _sanitize(data.stackTrace?.toString() ?? '', 16384),
            appVersion: info.version,
            platform: Platform.operatingSystem,
          );
        } catch (_) {
          // Reporting must never create another Talker error or affect the app.
        } finally {
          _reporting = false;
        }
      }
    } finally {
      _sending = false;
    }
  }

  String _sanitize(String value, int maxLength) {
    var result = value
        .replaceAll(
          RegExp(
            r'(password|passwd|token|ticket|authorization|cookie|student_id)([=:])[^\s&]+',
            caseSensitive: false,
          ),
          r'$1$2<redacted>',
        )
        .replaceAll(
          RegExp(r'Bearer\s+[^\s]+', caseSensitive: false),
          'Bearer <redacted>',
        );
    if (result.length > maxLength) result = result.substring(0, maxLength);
    return result;
  }
}
