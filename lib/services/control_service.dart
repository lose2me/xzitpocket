import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/control_config.dart';
import '../models/learning_question.dart';
import '../models/school_calendar.dart';
import 'control_crypto.dart';
import 'preferences_storage.dart';
import 'talker.dart';

class ControlRelease {
  final String latestVersion;
  final Uri downloadUrl;

  const ControlRelease({
    required this.latestVersion,
    required this.downloadUrl,
  });
}

class ControlConfigVersions {
  final String appRelease;
  final String schoolCalendar;

  const ControlConfigVersions({
    required this.appRelease,
    required this.schoolCalendar,
  });
}

class ControlApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  const ControlApiException(this.code, this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ControlService {
  static final ControlService instance = ControlService._();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );
  static const _stateKey = 'xzitpocket_control_state_v1';

  final String baseUrl;
  late final Dio _dio;

  Future<void>? _stateLoadFuture;
  Future<void>? _initializeFuture;
  Future<void>? _deviceFuture;
  Future<String?>? _refreshFuture;
  Future<void>? _loginFuture;
  Future<bool>? _healthFuture;
  Future<ControlConfigVersions>? _configVersionsFuture;
  Future<String?>? _loginBlockFuture;
  PackageInfo? _packageInfo;

  String? _installationId;
  ControlDeviceKey? _deviceKey;
  String? _deviceId;
  String? _deviceSerial;
  String? _deviceToken;
  String? _accessToken;
  String? _refreshToken;
  String? _sessionStudentId;
  DateTime? _accessExpiresAt;
  DateTime? _refreshExpiresAt;

  ControlService._()
    : baseUrl = configuredControlBaseUrl.trim().replaceFirst(
        RegExp(r'/$'),
        '',
      ) {
    if (isConfigured) {
      _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
          validateStatus: (status) => status != null,
        ),
      );
    }
  }

  bool get isConfigured {
    final uri = Uri.tryParse(baseUrl);
    return uri != null &&
        uri.hasScheme &&
        uri.host.isNotEmpty &&
        uri.scheme == 'https';
  }

  Future<void> initialize() {
    if (!isConfigured) return Future.value();
    return _initializeFuture ??= _initialize();
  }

  bool _serviceAvailable = false;

  bool get serviceAvailable => _serviceAvailable;

  Future<bool> checkHealth() {
    if (!isConfigured) {
      _serviceAvailable = false;
      return Future.value(false);
    }
    final pending = _healthFuture;
    if (pending != null) return pending;
    final future = _checkHealth();
    _healthFuture = future;
    return future.whenComplete(() {
      if (identical(_healthFuture, future)) _healthFuture = null;
    });
  }

  Future<bool> _checkHealth() async {
    try {
      await _request('GET', '/healthz');
      _serviceAvailable = true;
    } catch (_) {
      _serviceAvailable = false;
    }
    return _serviceAvailable;
  }

  Future<void> _initialize() async {
    try {
      await _loadState();
      await _ensureDevice();
      if (_refreshToken != null) {
        await _validAccessToken();
      }
      await _sendTelemetry('app_start');
    } catch (error, stackTrace) {
      talker.warning('Control 初始化失败', error, stackTrace);
    }
  }

  /// Returns a user-facing reason when control has banned the current device or
  /// disabled the account, or null when login is allowed. Any failure to reach
  /// control (or any other response) is treated as allowed so a control outage
  /// never blocks app usage.
  Future<String?> loginBlockReason(String studentId) {
    final normalized = studentId.trim();
    if (!isConfigured || normalized.isEmpty) return Future.value();
    final pending = _loginBlockFuture;
    if (pending != null) return pending;
    final future = _loginBlockReason(normalized);
    _loginBlockFuture = future;
    return future.whenComplete(() {
      if (identical(_loginBlockFuture, future)) _loginBlockFuture = null;
    });
  }

  Future<String?> _loginBlockReason(String studentId) async {
    try {
      return await _checkLoginEligibility(studentId)
          .timeout(const Duration(seconds: 3));
    } catch (error, stackTrace) {
      // Unreachable, slow, or otherwise unavailable control: allow the login.
      talker.warning('Control 登录资格检查失败，按允许处理', error, stackTrace);
      return null;
    }
  }

  Future<String?> _checkLoginEligibility(String studentId) async {
    await _loadState();
    await _ensureDevice();
    final token = _deviceToken;
    if (token == null) return null;
    try {
      await _request(
        'POST',
        '/api/v1/auth/login-eligibility',
        data: {'student_id': studentId},
        headers: {'Authorization': 'Device $token'},
      );
      return null;
    } on ControlApiException catch (error) {
      switch (error.code) {
        case 'device_revoked':
          return '该设备已被封禁，无法登录';
        case 'account_disabled':
          return error.message;
      }
      return null;
    }
  }

  Future<void> syncAfterOaLogin({
    required String studentId,
    required String displayName,
    String collegeName = '',
    String className = '',
    bool forceProfileUpdate = false,
  }) async {
    if (!isConfigured) return;
    final normalizedStudentId = studentId.trim();
    if (normalizedStudentId.isEmpty) return;
    final previous = _loginFuture;
    if (previous != null) await previous;
    final future = _syncAfterOaLogin(
      studentId: normalizedStudentId,
      displayName: displayName.trim(),
      collegeName: collegeName.trim(),
      className: className.trim(),
      forceProfileUpdate: forceProfileUpdate,
    );
    _loginFuture = future;
    try {
      await future;
    } catch (error, stackTrace) {
      talker.warning('Control 登录同步失败', error, stackTrace);
    } finally {
      if (identical(_loginFuture, future)) _loginFuture = null;
    }
  }

  Future<void> _syncAfterOaLogin({
    required String studentId,
    required String displayName,
    required String collegeName,
    required String className,
    required bool forceProfileUpdate,
    bool retryingDevice = false,
  }) async {
    await _loadState();
    await _ensureDevice();
    if (!forceProfileUpdate &&
        _sessionStudentId == studentId &&
        await _validAccessToken() != null) {
      return;
    }

    late final Map<String, dynamic> challengeResponse;
    try {
      challengeResponse = await _request(
        'POST',
        '/api/v1/auth/challenges',
        headers: {'Authorization': 'Device $_deviceToken'},
      );
    } on ControlApiException catch (error) {
      if (!retryingDevice && _isDeviceInvalid(error)) {
        _resetDevice();
        await _persistState();
        await _ensureDevice();
        return _syncAfterOaLogin(
          studentId: studentId,
          displayName: displayName,
          collegeName: collegeName,
          className: className,
          forceProfileUpdate: forceProfileUpdate,
          retryingDevice: true,
        );
      }
      rethrow;
    }
    final challengeId = challengeResponse['challenge_id']?.toString() ?? '';
    final challenge = challengeResponse['challenge']?.toString() ?? '';
    if (challengeId.isEmpty || challenge.isEmpty) {
      throw const ControlApiException(
        'invalid_challenge_response',
        '服务端返回的登录挑战无效',
      );
    }

    final assertedAt = DateTime.now().toUtc().toIso8601String();
    final alias = controlStudentAlias(studentId);
    final body = <String, dynamic>{
      'challenge_id': challengeId,
      'challenge': challenge,
      'device_serial': _deviceSerial,
      'student_id': studentId,
      'student_alias': alias,
      'display_name': displayName,
      'college_name': collegeName,
      'class_name': className,
      'asserted_at': assertedAt,
    };
    final signedFields = <String>[
      'xzitpocket-control-login',
      challengeId,
      challenge,
      _deviceSerial!,
      studentId,
      alias,
      displayName,
      if (collegeName.isNotEmpty || className.isNotEmpty) ...[
        collegeName,
        className,
      ],
      assertedAt,
    ];
    final signature = _deviceKey!.sign(controlCanonicalLines(signedFields));
    late final Map<String, dynamic> response;
    try {
      response = await _request(
        'POST',
        '/api/v1/auth/assertions',
        data: body,
        headers: {
          'Authorization': 'Device $_deviceToken',
          'X-Device-Signature': signature,
          'X-Device-Signed-At': assertedAt,
          'X-Installation-ID': _installationId,
        },
      );
    } on ControlApiException catch (error) {
      // A restored or server-recreated device can leave a valid token paired
      // with a different installation ID. Re-register once before surfacing
      // the failure to the caller.
      if (!retryingDevice && _isDeviceInvalid(error)) {
        _resetDevice();
        await _persistState();
        await _ensureDevice();
        return _syncAfterOaLogin(
          studentId: studentId,
          displayName: displayName,
          collegeName: collegeName,
          className: className,
          forceProfileUpdate: forceProfileUpdate,
          retryingDevice: true,
        );
      }
      rethrow;
    }
    _applySession(response, studentId: studentId);
    await _persistState();
    await _sendTelemetry('control_login_success');
  }

  Future<List<LearningQuestionBank>> fetchLearningQuestionBanks() =>
      syncLearningQuestionBanks(const {});

  /// Fetches question-bank summaries and only downloads full questions for
  /// banks that are new or whose server `updated_at` differs from [existing].
  /// Unchanged banks are returned from [existing] without a detail request, so
  /// a version-only sync costs a single summary request.
  Future<List<LearningQuestionBank>> syncLearningQuestionBanks(
    Map<String, LearningQuestionBank> existing,
  ) async {
    if (!isConfigured) {
      throw const ControlApiException(
        'control_not_configured',
        'Control 服务地址未配置',
      );
    }
    await initialize();
    final pendingLogin = _loginFuture;
    if (pendingLogin != null) await pendingLogin;
    final token = await _validAccessToken();
    if (token == null) {
      throw const ControlApiException(
        'control_login_required',
        '请先登录后读取在线题库',
        401,
      );
    }

    final summaries = <Map<String, dynamic>>[];
    final hiddenIds = <String>{};
    var offset = 0;
    const limit = 100;
    while (true) {
      final page = await _request(
        'GET',
        '/api/v1/question-banks?limit=$limit&offset=$offset',
        headers: {'Authorization': 'Bearer $token'},
      );
      final items = page['items'];
      if (items is List) {
        summaries.addAll(items.whereType<Map>().map(_stringMap));
      }
      final hidden = page['hidden'];
      if (hidden is List) {
        for (final item in hidden.whereType<Map>()) {
          final id = item['id']?.toString() ?? '';
          if (id.isNotEmpty && item['status']?.toString() != 'active') {
            hiddenIds.add(id);
          }
        }
      }
      final total = _asInt(page['total']) ?? summaries.length;
      if (summaries.length >= total || items is! List || items.isEmpty) break;
      offset = summaries.length;
    }
    summaries.sort((a, b) {
      final order = (_asInt(a['orderId']) ?? 0).compareTo(
        _asInt(b['orderId']) ?? 0,
      );
      return order != 0
          ? order
          : (a['name']?.toString() ?? '').compareTo(
              b['name']?.toString() ?? '',
            );
    });

    final banks = <LearningQuestionBank>[];
    final activeIds = <String>{};
    for (final summary in summaries) {
      final id = summary['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      activeIds.add(id);
      final updatedAt = summary['updated_at']?.toString() ?? '';
      final cached = existing[id];
      if (cached != null && cached.updatedAt == updatedAt && !cached.hidden) {
        // Summary timestamp is unchanged, so the cached questions are current.
        banks.add(cached);
        continue;
      }
      final summaryBank = LearningQuestionBank.fromJson({
        'id': id,
        'orderId': summary['orderId'],
        'new': summary['new'],
        'name': summary['name'],
        'requiresCDK': summary['requiresCDK'] == true,
        'updatedAt': updatedAt,
        'questions': const [],
      });
      try {
        final response = await _request(
          'GET',
          '/api/v1/question-banks/${Uri.encodeComponent(id)}',
          headers: {'Authorization': 'Bearer $token'},
        );
        final rawBank = response['questionBank'];
        banks.add(
          LearningQuestionBank.fromJson(
            rawBank is Map<String, dynamic>
                ? <String, dynamic>{...rawBank, 'updatedAt': updatedAt}
                : <String, dynamic>{...response, 'updatedAt': updatedAt},
          ),
        );
      } on ControlApiException catch (error) {
        if (error.code != 'question_bank_locked') rethrow;
        banks.add(
          LearningQuestionBank.fromJson({
            'id': summaryBank.id,
            'orderId': summaryBank.orderId,
            'new': summaryBank.isNew,
            'name': summaryBank.name,
            'requiresCDK': summaryBank.requiresCDK,
            'locked': true,
            'updatedAt': updatedAt,
            'questions': const [],
          }),
        );
      }
    }

    // Banks that are disabled/draft stay cached but marked hidden, so their
    // questions and saved collections survive until the bank is re-enabled.
    // Anything absent from both the active and hidden lists was deleted.
    for (final cached in existing.values) {
      if (activeIds.contains(cached.id)) continue;
      if (hiddenIds.contains(cached.id)) {
        banks.add(cached.copyWith(hidden: true));
      }
    }
    return banks;
  }

  Future<List<LearningQuestion>> fetchLearningQuestions() async {
    final banks = await fetchLearningQuestionBanks();
    return [for (final bank in banks) ...bank.questions];
  }

  Future<void> redeemLibraryCdk(String code, String questionBankId) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw const ControlApiException('invalid_library_cdk', '请输入 CDK');
    }
    await initialize();
    final pendingLogin = _loginFuture;
    if (pendingLogin != null) await pendingLogin;
    final token = await _validAccessToken();
    if (token == null) {
      throw const ControlApiException(
        'control_login_required',
        '请先登录后兑换 CDK',
        401,
      );
    }
    await _request(
      'POST',
      '/api/v1/library/cdks/redeem',
      data: {'code': normalized, 'question_bank_id': questionBankId},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<String> createShareCode({
    required String suffix,
    required Map<String, dynamic> data,
  }) async {
    if (!isConfigured) {
      throw const ControlApiException(
        'control_not_configured',
        'Control 服务地址未配置',
      );
    }
    await initialize();
    final pendingLogin = _loginFuture;
    if (pendingLogin != null) await pendingLogin;
    final token = await _validAccessToken();
    if (token == null) {
      throw const ControlApiException(
        'control_login_required',
        '请先登录后生成分享码',
        401,
      );
    }
    final response = await _request(
      'POST',
      '/api/v1/share-codes',
      data: {'suffix': suffix, 'data': data},
      headers: {'Authorization': 'Bearer $token'},
    );
    final code = response['code']?.toString().trim() ?? '';
    if (code.length != 6) {
      throw const ControlApiException(
        'invalid_share_code_response',
        '服务端返回的分享码无效',
      );
    }
    return code;
  }

  Future<Map<String, dynamic>> fetchShareCode(String code) async {
    if (!isConfigured) {
      throw const ControlApiException(
        'control_not_configured',
        'Control 服务地址未配置',
      );
    }
    final response = await _request(
      'GET',
      '/api/v1/share-codes/${Uri.encodeComponent(code.trim())}',
    );
    final data = response['data'];
    if (data is! Map) {
      throw const ControlApiException('invalid_share_data', '分享码数据格式无效');
    }
    return _stringMap(data);
  }

  Future<ControlRelease?> checkForUpdate() async {
    if (!isConfigured) return null;
    try {
      final info = await _getPackageInfo();
      final response = await _request('GET', '/api/v1/app/release');
      final latestVersion = response['latestVersion']?.toString().trim() ?? '';
      final downloadUrl = Uri.tryParse(
        response['downloadUrl']?.toString().trim() ?? '',
      );
      final controlUri = Uri.parse(baseUrl);
      if (latestVersion.isEmpty ||
          downloadUrl == null ||
          !isAllowedControlDownloadUrl(controlUri, downloadUrl) ||
          !isControlVersionNewer(latestVersion, info.version)) {
        return null;
      }
      return ControlRelease(
        latestVersion: latestVersion,
        downloadUrl: downloadUrl,
      );
    } catch (error, stackTrace) {
      talker.warning('检查新版本失败', error, stackTrace);
      return null;
    }
  }

  Future<ControlConfigVersions> fetchConfigVersions() {
    if (!isConfigured) {
      return Future.error(
        const ControlApiException('control_not_configured', 'Control 服务地址未配置'),
      );
    }
    final pending = _configVersionsFuture;
    if (pending != null) return pending;
    final future = _fetchConfigVersions();
    _configVersionsFuture = future;
    return future.whenComplete(() {
      if (identical(_configVersionsFuture, future)) {
        _configVersionsFuture = null;
      }
    });
  }

  Future<ControlConfigVersions> _fetchConfigVersions() async {
    final response = await _request('GET', '/api/v1/config/versions');
    _serviceAvailable = true;
    return ControlConfigVersions(
      appRelease: response['appRelease']?.toString() ?? '',
      schoolCalendar: response['schoolCalendar']?.toString() ?? '',
    );
  }

  /// Downloads the school calendar only when control reports a version the
  /// local cache does not have. Returns true when [semesterCalendar] changed;
  /// the caller decides whether to re-apply cloud course adjustments.
  Future<bool> refreshSchoolCalendarIfChanged(PreferencesStorage prefs) async {
    if (!isConfigured) return false;
    await initialize();
    late final ControlConfigVersions versions;
    try {
      versions = await fetchConfigVersions();
    } catch (_) {
      _serviceAvailable = false;
      return false;
    }
    if (prefs.getSchoolCalendarCache() != null &&
        prefs.getSchoolCalendarVersion() == versions.schoolCalendar) {
      return false;
    }
    final days = await fetchSchoolCalendar();
    semesterCalendar.replaceDays(days);
    await prefs.setSchoolCalendarCache(schoolCalendarDaysToJson(days));
    await prefs.setSchoolCalendarVersion(versions.schoolCalendar);
    return true;
  }

  /// Loads the administrator-managed school calendar. This endpoint is public
  /// because the calendar contains no account-specific information.
  Future<List<SchoolDay>> fetchSchoolCalendar() async {
    if (!isConfigured) {
      throw const ControlApiException(
        'control_not_configured',
        'Control 服务地址未配置',
      );
    }
    final response = await _request('GET', '/api/v1/school-calendar');
    try {
      return schoolCalendarDaysFromJson(jsonEncode(response));
    } catch (error) {
      final message = error is FormatException
          ? error.message
          : 'Control 返回的校历数据格式无效';
      throw ControlApiException('invalid_school_calendar', message);
    }
  }

  Future<void> track(
    String type, {
    Map<String, dynamic> properties = const {},
  }) async {
    if (!isConfigured) return;
    try {
      await _loadState();
      await _ensureDevice();
      await _sendTelemetry(type, properties: properties);
    } catch (error, stackTrace) {
      talker.warning('Control 事件上报失败: $type', error, stackTrace);
    }
  }

  Future<void> reportErrorLog({
    required String eventId,
    required DateTime occurredAt,
    required String title,
    required String message,
    required String error,
    required String stackTrace,
    required String appVersion,
    required String platform,
  }) async {
    if (!isConfigured) return;
    await _loadState();
    final pendingLogin = _loginFuture;
    if (pendingLogin != null) await pendingLogin;
    final token = await _validAccessToken();
    if (token == null || _sessionStudentId == null) return;
    await _request(
      'POST',
      '/api/v1/error-reports',
      data: {
        'event_id': eventId,
        'occurred_at': occurredAt.toUtc().toIso8601String(),
        'app_version': appVersion,
        'platform': platform,
        'title': title,
        'message': message,
        'error': error,
        'stack_trace': stackTrace,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<void> logout() async {
    if (!isConfigured) return;
    try {
      final pendingLogin = _loginFuture;
      if (pendingLogin != null) await pendingLogin;
      await _loadState();
      final token = await _validAccessToken();
      if (token != null) {
        await _sendTelemetry('logout');
        await _request(
          'POST',
          '/api/v1/auth/revoke',
          headers: {'Authorization': 'Bearer $token'},
        );
      }
    } catch (error, stackTrace) {
      talker.warning('Control 退出同步失败', error, stackTrace);
    } finally {
      _clearSession();
      await _persistState();
    }
  }

  Future<void> _sendTelemetry(
    String type, {
    Map<String, dynamic> properties = const {},
    bool retryingDevice = false,
  }) async {
    if (_deviceToken == null) return;
    final info = await _getPackageInfo();
    final token = await _validAccessToken();
    final headers = token == null
        ? {'Authorization': 'Device $_deviceToken'}
        : {'Authorization': 'Bearer $token'};
    try {
      await _request(
        'POST',
        '/api/v1/telemetry/events',
        data: [
          {
            'event_id': controlRandomToken(24),
            'type': type,
            'occurred_at': DateTime.now().toUtc().toIso8601String(),
            'properties': {
              'app_version': info.version,
              'platform': Platform.operatingSystem,
              ...properties,
            },
          },
        ],
        headers: headers,
      );
    } on ControlApiException catch (error) {
      if (!retryingDevice && _isDeviceInvalid(error)) {
        _resetDevice();
        await _persistState();
        await _ensureDevice();
        return _sendTelemetry(
          type,
          properties: properties,
          retryingDevice: true,
        );
      }
      rethrow;
    }
  }

  Future<void> _ensureDevice() {
    final pending = _deviceFuture;
    if (pending != null) return pending;
    final future = _ensureDeviceImpl();
    _deviceFuture = future;
    return future.whenComplete(() {
      if (identical(_deviceFuture, future)) _deviceFuture = null;
    });
  }

  Future<void> _ensureDeviceImpl({bool retrying = false}) async {
    await _loadState();
    if (_installationId == null || _deviceKey == null) {
      _installationId = controlRandomToken(24);
      _deviceKey = ControlDeviceKey.generate();
      await _persistState();
    }
    if (_deviceToken != null && _deviceSerial != null) return;

    final info = await _getPackageInfo();
    final createdAt = DateTime.now().toUtc().toIso8601String();
    final publicKey = _deviceKey!.publicKeyEncoded;
    final platform = Platform.operatingSystem;
    final signature = _deviceKey!.sign(
      controlCanonicalLines([
        'xzitpocket-control-device',
        _installationId!,
        publicKey,
        platform,
        info.version,
        createdAt,
      ]),
    );
    try {
      final response = await _request(
        'POST',
        '/api/v1/devices/register',
        data: {
          'installation_id': _installationId,
          'public_key': publicKey,
          'platform': platform,
          'app_version': info.version,
          'created_at': createdAt,
        },
        headers: {'X-Device-Signature': signature},
      );
      _deviceId = response['device_id']?.toString();
      _deviceSerial = response['device_serial']?.toString();
      _deviceToken = response['device_token']?.toString();
      if (_deviceSerial?.isEmpty != false || _deviceToken?.isEmpty != false) {
        throw const ControlApiException(
          'invalid_device_response',
          '服务端返回的设备信息无效',
        );
      }
      await _persistState();
    } on ControlApiException catch (error) {
      if (!retrying &&
          (error.code == 'device_already_registered' ||
              error.code == 'installation_exists')) {
        _resetDevice();
        await _persistState();
        await _ensureDeviceImpl(retrying: true);
        return;
      }
      rethrow;
    }
  }

  Future<String?> _validAccessToken() async {
    final now = DateTime.now().toUtc();
    if (_accessToken != null &&
        _accessExpiresAt?.isAfter(now.add(const Duration(seconds: 30))) ==
            true) {
      return _accessToken;
    }
    final pending = _refreshFuture;
    if (pending != null) return pending;
    final future = _refreshAccessToken();
    _refreshFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshFuture, future)) _refreshFuture = null;
    }
  }

  Future<String?> _refreshAccessToken() async {
    final now = DateTime.now().toUtc();
    if (_refreshToken == null ||
        _refreshExpiresAt?.isAfter(now) != true ||
        _deviceSerial == null ||
        _installationId == null ||
        _deviceKey == null) {
      _clearSession();
      await _persistState();
      return null;
    }
    try {
      final refreshToken = _refreshToken!;
      final signedAt = now.toIso8601String();
      final signature = _deviceKey!.sign(
        controlCanonicalLines([
          'xzitpocket-control-refresh',
          _deviceSerial!,
          refreshToken,
          signedAt,
        ]),
      );
      final response = await _request(
        'POST',
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
        headers: {
          'X-Device-Signature': signature,
          'X-Device-Signed-At': signedAt,
          'X-Installation-ID': _installationId,
        },
      );
      _applySession(response, studentId: _sessionStudentId);
      await _persistState();
      return _accessToken;
    } on ControlApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        _clearSession();
        await _persistState();
        return null;
      }
      rethrow;
    }
  }

  void _applySession(
    Map<String, dynamic> response, {
    required String? studentId,
  }) {
    _accessToken = response['access_token']?.toString();
    _refreshToken = response['refresh_token']?.toString();
    _accessExpiresAt = DateTime.tryParse(
      response['expires_at']?.toString() ?? '',
    )?.toUtc();
    _refreshExpiresAt = DateTime.tryParse(
      response['refresh_expires_at']?.toString() ?? '',
    )?.toUtc();
    _sessionStudentId = studentId;
    if (_accessToken?.isEmpty != false || _refreshToken?.isEmpty != false) {
      throw const ControlApiException(
        'invalid_session_response',
        '服务端返回的会话信息无效',
      );
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? headers,
  }) async {
    late final Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        path,
        data: data,
        options: Options(method: method, headers: headers),
      );
    } on DioException catch (error) {
      throw ControlApiException(
        'control_unavailable',
        'Control 服务暂时不可用',
        error.response?.statusCode,
      );
    }

    final body = response.data;
    final map = body is Map ? _stringMap(body) : <String, dynamic>{};
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      final rawError = map['error'];
      final error = rawError is Map
          ? _stringMap(rawError)
          : const <String, dynamic>{};
      throw ControlApiException(
        error['code']?.toString() ?? 'control_request_failed',
        error['message']?.toString() ?? 'Control 请求失败',
        status,
      );
    }
    return map;
  }

  Future<void> _loadState() {
    final pending = _stateLoadFuture;
    if (pending != null) return pending;
    final future = _loadStateImpl();
    _stateLoadFuture = future;
    return future.whenComplete(() {
      if (identical(_stateLoadFuture, future)) _stateLoadFuture = null;
    });
  }

  Future<void> _loadStateImpl() async {
    final raw = await _secureStorage.read(key: _stateKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final state = _stringMap(jsonDecode(raw) as Map);
      _installationId = _nonEmpty(state['installation_id']);
      final privateKey = _nonEmpty(state['private_key']);
      if (privateKey != null) {
        _deviceKey = ControlDeviceKey.fromPrivateKey(privateKey);
      }
      _deviceId = _nonEmpty(state['device_id']);
      _deviceSerial = _nonEmpty(state['device_serial']);
      _deviceToken = _nonEmpty(state['device_token']);
      _accessToken = _nonEmpty(state['access_token']);
      _refreshToken = _nonEmpty(state['refresh_token']);
      _sessionStudentId = _nonEmpty(state['session_student_id']);
      _accessExpiresAt = _parseStoredDate(state['access_expires_at']);
      _refreshExpiresAt = _parseStoredDate(state['refresh_expires_at']);
    } catch (error, stackTrace) {
      talker.warning('Control 本地状态损坏，已重新创建设备身份', error, stackTrace);
      _resetDevice();
      await _secureStorage.delete(key: _stateKey);
    }
  }

  Future<void> _persistState() => _secureStorage.write(
    key: _stateKey,
    value: jsonEncode({
      if (_installationId != null) 'installation_id': _installationId,
      if (_deviceKey != null) 'private_key': _deviceKey!.privateKeyEncoded,
      if (_deviceId != null) 'device_id': _deviceId,
      if (_deviceSerial != null) 'device_serial': _deviceSerial,
      if (_deviceToken != null) 'device_token': _deviceToken,
      if (_accessToken != null) 'access_token': _accessToken,
      if (_refreshToken != null) 'refresh_token': _refreshToken,
      if (_sessionStudentId != null) 'session_student_id': _sessionStudentId,
      if (_accessExpiresAt != null)
        'access_expires_at': _accessExpiresAt!.toIso8601String(),
      if (_refreshExpiresAt != null)
        'refresh_expires_at': _refreshExpiresAt!.toIso8601String(),
    }),
  );

  Future<PackageInfo> _getPackageInfo() async =>
      _packageInfo ??= await PackageInfo.fromPlatform();

  void _clearSession() {
    _accessToken = null;
    _refreshToken = null;
    _sessionStudentId = null;
    _accessExpiresAt = null;
    _refreshExpiresAt = null;
  }

  void _resetDevice() {
    _clearSession();
    _installationId = null;
    _deviceKey = null;
    _deviceId = null;
    _deviceSerial = null;
    _deviceToken = null;
  }
}

bool isControlVersionNewer(String candidate, String current) {
  final candidateParts = _versionParts(candidate);
  final currentParts = _versionParts(current);
  final length = candidateParts.length > currentParts.length
      ? candidateParts.length
      : currentParts.length;
  for (var index = 0; index < length; index++) {
    final left = index < candidateParts.length ? candidateParts[index] : 0;
    final right = index < currentParts.length ? currentParts[index] : 0;
    if (left != right) return left > right;
  }
  return false;
}

bool isAllowedControlDownloadUrl(Uri controlUri, Uri downloadUri) =>
    downloadUri.hasScheme &&
    downloadUri.scheme == 'https' &&
    (downloadUri.host == controlUri.host ||
        configuredUpdateDownloadHosts.contains(downloadUri.host));

bool _isDeviceInvalid(ControlApiException error) =>
    error.code == 'invalid_device_token' ||
    error.code == 'device_revoked' ||
    error.code == 'installation_mismatch' ||
    error.code == 'device_mismatch';

List<int> _versionParts(String value) {
  final core = value.trim().split(RegExp(r'[+-]')).first;
  return [for (final part in core.split('.')) int.tryParse(part) ?? 0];
}

Map<String, dynamic> _stringMap(Map<dynamic, dynamic> value) => {
  for (final entry in value.entries) entry.key.toString(): entry.value,
};

String? _nonEmpty(dynamic value) {
  final string = value?.toString();
  return string == null || string.isEmpty ? null : string;
}

DateTime? _parseStoredDate(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toUtc();

int? _asInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
