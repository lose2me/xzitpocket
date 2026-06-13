import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import '../constants/network_config.dart';
import '../utils/cas_encrypt.dart';
import 'cas_service.dart';
import 'dio_factory.dart';

class ResetAccount {
  final String sid;
  final String info;
  const ResetAccount({required this.sid, required this.info});
}

class VerifyResult {
  final String validateId;
  final List<ResetAccount> accounts;
  const VerifyResult({required this.validateId, required this.accounts});
}

class PasswordResetService {
  Dio? _dio;
  CookieJar? _jar;

  Dio _ensureDio() {
    if (_dio != null) return _dio!;
    _jar = CookieJar();
    _dio = DioFactory.createNaked(
      cookieJar: _jar!,
      connectTimeout: requestTimeout,
      receiveTimeout: requestTimeout,
    );
    _dio!.options.headers['User-Agent'] = kUserAgent;
    return _dio!;
  }

  void dispose() {
    _dio?.close(force: true);
    _dio = null;
    _jar = null;
  }

  Future<void> sendCode(String phone) async {
    final dio = _ensureDio();

    await dio.get('${findPwdUrl}index.zf');

    final resp = await dio.post(
      '${findPwdUrl}byPhone.zf',
      data: {'phone': phone, 'validCode': '0'},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final result = resp.data as Map<String, dynamic>;
    if (result['code'] != '0') {
      throw AuthException(
        (result['content'] as String?) ?? '发送失败',
      );
    }
  }

  Future<VerifyResult> verifyCode(String phone, String code) async {
    final dio = _ensureDio();

    final resp = await dio.post(
      '${findPwdUrl}validateCodePhone.zf',
      data: {'phone': phone, 'yzm': code},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final result = resp.data as Map<String, dynamic>;
    if (result['code'] != '0') {
      throw AuthException(
        (result['content'] as String?) ?? '验证失败',
      );
    }

    final list = (result['multipleAccountList'] as List?) ?? [];
    final accounts = list
        .map((a) => ResetAccount(
              sid: (a['zgh'] ?? '') as String,
              info: (a['jsxx'] ?? '') as String,
            ))
        .toList();

    return VerifyResult(
      validateId: result['validateID'] as String,
      accounts: accounts,
    );
  }

  Future<void> resetPassword(
    String phone,
    String newPassword,
    String sid,
    String validateId,
  ) async {
    final err = validatePassword(newPassword);
    if (err.isNotEmpty) throw AuthException(err);

    final dio = _ensureDio();

    final pkResp = await dio.get(
      '$imBaseUrl/securitycenter/findPwd/getPublicKey.zf',
    );
    final parts = (pkResp.data as String).trim().split(';');
    if (parts.length < 2) throw AuthException('获取密钥失败');
    final modulus = parts[0];
    final exponent = parts[1];

    final encrypted = casEncryptPassword(newPassword, modulus, exponent);

    final resp = await dio.post(
      '${findPwdUrl}updatePwdPhone.zf',
      data: {
        'zgh': sid,
        'phone': phone,
        'subNewPwd': encrypted,
        'validateID': validateId,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final result = resp.data as Map<String, dynamic>;
    if (result['code'] != '0') {
      throw AuthException(
        (result['content'] as String?) ?? '重置失败',
      );
    }
  }

  static String validatePassword(String password) {
    if (password.length < 10) return '密码长度不低于10位';
    final checks = <(RegExp, String)>[
      (RegExp(r'[A-Z]'), '大写字母'),
      (RegExp(r'[a-z]'), '小写字母'),
      (RegExp(r'[0-9]'), '数字'),
      (RegExp(r'''[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>/?~`]'''), '特殊字符'),
    ];
    final missing = checks
        .where((c) => !c.$1.hasMatch(password))
        .map((c) => c.$2)
        .toList();
    if (missing.isNotEmpty) return '密码必须包含${missing.join("、")}';
    return '';
  }
}
