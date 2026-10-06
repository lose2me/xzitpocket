import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/models/school_calendar.dart';
import 'package:xzitpocket/services/control_service.dart';
import 'package:xzitpocket/services/learning_repository.dart';
import 'package:xzitpocket/services/preferences_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ControlAdapter adapter;
  late ControlService service;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: '掌上徐工',
      packageName: 'live.xuda.xzitpocket',
      version: '2.1.0',
      buildNumber: '2100',
      buildSignature: '',
    );
    adapter = _ControlAdapter();
    service = ControlService.forTesting(adapter: adapter);
  });

  Future<void> login({bool force = false}) => service.syncAfterOaLogin(
    studentId: '20260001',
    displayName: '测试用户',
    forceProfileUpdate: force,
  );

  for (final (status, code) in [
    (401, 'unauthorized'),
    (403, 'account_disabled'),
  ]) {
    test('login sync replaces a rejected session ($code)', () async {
      await service.initialize();
      await login();
      adapter.handler = (options) =>
          options.path == '/api/v1/share-codes' ? _error(status, code) : null;

      await expectLater(
        service.createShareCode(suffix: '2', data: {'version': 1}),
        throwsA(isA<ControlApiException>()),
      );

      adapter.handler = null;
      await login();
      expect(adapter.logins, 2);
      expect(adapter.registrations, 1);
    });
  }

  test('a locked question bank preserves the authenticated session', () async {
    await service.initialize();
    await login();
    adapter.handler = (options) {
      if (options.uri.path == '/api/v1/question-banks') {
        return _json({
          'items': [
            {
              'id': 'QB-001',
              'orderId': 1,
              'name': '受保护题库',
              'requiresCDK': true,
              'updated_at': '2026-10-06T00:00:00Z',
            },
          ],
          'total': 1,
          'hidden': [],
        });
      }
      if (options.uri.path == '/api/v1/question-banks/QB-001') {
        return _error(403, 'question_bank_locked');
      }
      return null;
    };

    final banks = await service.fetchLearningQuestionBanks();
    expect(banks.single.locked, isTrue);
    await login();
    expect(adapter.logins, 1);
  });

  test('a late rejection cannot clear a newer session', () async {
    await service.initialize();
    await login();
    final requested = Completer<void>();
    final response = Completer<ResponseBody>();
    adapter.handler = (options) {
      if (options.uri.path == '/api/v1/question-banks') {
        requested.complete();
        return response.future;
      }
      return null;
    };
    final fetch = expectLater(
      service.fetchLearningQuestionBanks(),
      throwsA(isA<ControlApiException>()),
    );
    await requested.future;
    await login(force: true);
    response.complete(_error(401, 'unauthorized'));
    await fetch;

    adapter.handler = null;
    await login();
    expect(adapter.logins, 2);
  });

  test('telemetry never re-registers a revoked device', () async {
    await service.initialize();
    adapter.handler = (options) =>
        (options.path == '/api/v1/telemetry/events' ||
            options.path == '/api/v1/auth/login-eligibility')
        ? _error(401, 'device_revoked')
        : null;

    await service.track('foreground');
    expect(adapter.registrations, 1);
    expect(await service.loginBlockReason('20260001'), '该设备已被封禁，无法登录');
  });

  test('an invalid device token still recovers after a server reset', () async {
    await service.initialize();
    var rejected = false;
    adapter.handler = (options) {
      if (options.path == '/api/v1/telemetry/events' && !rejected) {
        rejected = true;
        return _error(401, 'invalid_device_token');
      }
      return null;
    };

    await service.track('foreground');
    expect(adapter.registrations, 2);
  });

  for (final rejectedPath in [
    '/api/v1/question-banks',
    '/api/v1/question-banks/QB-001',
  ]) {
    test('disabled library marks risk state ($rejectedPath)', () async {
      await service.initialize();
      await login();
      final prefs = PreferencesStorage();
      await prefs.init();
      final repository = LearningRepository(
        preferencesStorage: prefs,
        bankSyncFetcher: service.syncLearningQuestionBanks,
      );
      addTearDown(repository.dispose);
      adapter.handler = (options) {
        if (options.uri.path == rejectedPath) {
          return _error(403, 'user_unavailable');
        }
        if (options.uri.path == '/api/v1/question-banks') {
          return _json({
            'items': [
              {
                'id': 'QB-001',
                'name': '题库',
                'updated_at': '2026-10-06T00:00:00.001Z',
              },
            ],
            'total': 1,
            'hidden': [],
          });
        }
        return null;
      };
      await expectLater(
        repository.sync(),
        throwsA(
          isA<ControlApiException>().having(
            (error) => error.code,
            'code',
            'user_unavailable',
          ),
        ),
      );
      expect(repository.libraryUnavailable, isTrue);

      adapter.handler = (options) =>
          options.uri.path == '/api/v1/question-banks'
          ? _json({'items': [], 'total': 0, 'hidden': []})
          : null;
      await login(force: true);
      await repository.sync();
      expect(repository.libraryUnavailable, isFalse);
    });
  }

  test('bank sync detects updates within the same second', () async {
    await service.initialize();
    await login();
    var revision = 1;
    var detailRequests = 0;
    adapter.handler = (options) {
      if (options.uri.path == '/api/v1/question-banks') {
        return _json({
          'items': [
            {
              'id': 'QB-001',
              'orderId': 1,
              'name': '题库 $revision',
              'requiresCDK': false,
              'updated_at': '2026-10-06T00:00:00.00${revision}Z',
            },
          ],
          'total': 1,
          'hidden': [],
        });
      }
      if (options.uri.path == '/api/v1/question-banks/QB-001') {
        detailRequests++;
        return _json({
          'questionBank': {
            'id': 'QB-001',
            'orderId': 1,
            'name': '题库 $revision',
            'requiresCDK': false,
            'questions': [],
          },
        });
      }
      return null;
    };

    final first = (await service.fetchLearningQuestionBanks()).single;
    revision = 2;
    final second = (await service.syncLearningQuestionBanks({first.id: first}))
        .single;
    expect(second.name, '题库 2');
    expect(second.updatedAt, '2026-10-06T00:00:00.002Z');
    expect(detailRequests, 2);

    await service.syncLearningQuestionBanks({second.id: second});
    expect(detailRequests, 2);
  });

  test('calendar refresh detects updates within the same second', () async {
    final originalDays = semesterCalendar.days.toList();
    addTearDown(() => semesterCalendar.replaceDays(originalDays));
    final prefs = PreferencesStorage();
    await prefs.init();
    var revision = 1;
    var calendarRequests = 0;
    adapter.handler = (options) {
      if (options.uri.path == '/api/v1/config/versions') {
        return _json({
          'appRelease': '',
          'schoolCalendar': '2026-10-06T00:00:00.00${revision}Z',
        });
      }
      if (options.uri.path == '/api/v1/school-calendar') {
        calendarRequests++;
        return _json({
          'days': [
            {'date': '2026-10-06', 'name': '校历 $revision', 'adjustment': ''},
          ],
          'updatedAt': '2026-10-06T00:00:00.00${revision}Z',
        });
      }
      return null;
    };

    expect(await service.refreshSchoolCalendarIfChanged(prefs), isTrue);
    revision = 2;
    expect(await service.refreshSchoolCalendarIfChanged(prefs), isTrue);
    expect(semesterCalendar.days.single.name, '校历 2');
    expect(prefs.getSchoolCalendarVersion(), '2026-10-06T00:00:00.002Z');
    expect(await service.refreshSchoolCalendarIfChanged(prefs), isFalse);
    expect(calendarRequests, 2);
  });
}

ResponseBody _json(Map<String, dynamic> data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody _error(int status, String code) => _json({
  'error': {'code': code, 'message': code},
}, status);

class _ControlAdapter implements HttpClientAdapter {
  int registrations = 0;
  int logins = 0;
  FutureOr<ResponseBody?> Function(RequestOptions)? handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final overridden = await handler?.call(options);
    if (overridden != null) return overridden;
    switch (options.uri.path) {
      case '/api/v1/devices/register':
        registrations++;
        return _json({
          'device_id': 'dev_1',
          'device_serial': 'dev_serial_$registrations',
          'device_token': 'device_token_$registrations',
        }, 201);
      case '/api/v1/auth/challenges':
        return _json({'challenge_id': 'ch_1', 'challenge': 'challenge'}, 201);
      case '/api/v1/auth/assertions':
        logins++;
        return _json({
          'access_token': 'access_$logins',
          'refresh_token': 'refresh_$logins',
          'expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 15))
              .toIso8601String(),
          'refresh_expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(days: 30))
              .toIso8601String(),
        }, 201);
      case '/api/v1/telemetry/events':
        return _json({'accepted': 1}, 202);
      case '/api/v1/auth/login-eligibility':
        return _json({'allowed': true});
      default:
        throw StateError('Unexpected control request: ${options.uri.path}');
    }
  }

  @override
  void close({bool force = false}) {}
}
