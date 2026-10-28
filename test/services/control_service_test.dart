import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/constants/time_slots.dart';
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
    // Most scenarios model a logged-in student; gate tests close it explicitly.
    service.updateLoginGate('20260001');
  });

  Future<void> login({bool force = false}) => service.syncAfterOaLogin(
    studentId: '20260001',
    displayName: '测试用户',
    forceProfileUpdate: force,
  );

  for (final missingField in [
    'display_name',
    'college_name',
    'class_name',
    'major_name',
  ]) {
    test('authenticated profile sync restores missing $missingField', () async {
      await login();
      adapter.handler = (options) {
        if (options.uri.path != '/api/v1/me') return null;
        expect(options.headers['Authorization'], 'Bearer access_1');
        return _json({
          'user': {
            'display_name': '测试用户',
            'college_name': '学院',
            'class_name': '班级',
            'major_name': '专业',
            missingField: '',
          },
        });
      };
      await service
          .syncAfterOaLogin(
            studentId: '20260001',
            displayName: '测试用户',
            collegeName: '学院',
            className: '班级',
            majorName: '专业',
          )
          .timeout(const Duration(seconds: 5));
      expect(adapter.logins, 2);
      expect(
        adapter.requests.where((r) => r.uri.path == '/api/v1/me'),
        hasLength(1),
      );
    });
  }

  for (final status in [200, 401, 503]) {
    test(
      'profile check handles HTTP $status without duplicate login',
      () async {
        await login();
        adapter.handler = (options) {
          if (options.uri.path != '/api/v1/me') return null;
          expect(options.headers['Authorization'], 'Bearer access_1');
          return status == 200
              ? _json({
                  'user': {'display_name': '测试用户'},
                })
              : _error(status, status == 401 ? 'unauthorized' : 'unavailable');
        };
        await login().timeout(const Duration(seconds: 5));
        expect(adapter.logins, status == 401 ? 2 : 1);
      },
    );
  }

  test(
    'login candidates carry their own student ID before the gate opens',
    () async {
      service.updateLoginGate(null);
      expect(await service.loginBlockReason('20260002'), isNull);
      final requests = adapter.requests.where(
        (request) => request.method == 'POST',
      );
      expect(requests.map((request) => request.uri.path), [
        '/api/v1/devices/register',
        '/api/v1/auth/login-eligibility',
      ]);
      for (final request in requests) {
        expect(request.headers['X-Student-ID'], '20260002');
      }
      service.updateLoginGate('20260002');
      await service.syncAfterOaLogin(studentId: '20260002', displayName: '用户');
      for (final request in adapter.requests.where(
        (request) => request.method == 'POST',
      )) {
        expect(request.headers['X-Student-ID'], '20260002');
      }
    },
  );

  test('all control reports and uploads use the authenticated student', () async {
    await service.initialize();
    await login();
    // Typing another candidate must not relabel an existing session's reports.
    service.updateLoginGate('20260002');
    adapter.requests.clear();
    adapter.handler = (options) {
      switch (options.uri.path) {
        case '/api/v1/share-codes':
          return _json({'code': '123456'});
        case '/api/v1/resource-center/submissions':
          return _json({
            'id': 'ticket',
            'files': [
              {
                'id': 'file',
                'name': 'test.pdf',
                'upload_url': 'https://cos.example/file',
              },
            ],
          });
        default:
          return _json({});
      }
    };
    await service.track('foreground');
    expect(
      await service.uploadCourses(items: [(code: 'C1', name: '课程', books: [])]),
      isTrue,
    );
    await service.reportErrorLog(
      eventId: 'e1',
      occurredAt: DateTime.now(),
      title: '',
      message: '',
      error: '',
      stackTrace: '',
      appVersion: '2.2.0',
      platform: 'android',
    );
    await service.createShareCode(suffix: '1', data: {});
    await service.redeemLibraryCdk('test', 'QB1');
    await service.createResourceUploadTicket(
      kind: 'resource',
      courseCode: 'C1',
      name: 'test',
      files: [
        const ResourceUploadFile(
          name: 'test.pdf',
          format: 'pdf',
          md5: 'md5',
          sizeBytes: 1,
        ),
      ],
    );
    await service.completeResourceUpload('ticket');
    await service.abortResourceUpload('ticket');
    await service.logout();
    expect(
      adapter.requests.map(
        (request) => '${request.method} ${request.uri.path}',
      ),
      containsAll([
        'POST /api/v1/telemetry/events',
        'POST /api/v1/courses',
        'POST /api/v1/error-reports',
        'POST /api/v1/share-codes',
        'POST /api/v1/library/cdks/redeem',
        'POST /api/v1/resource-center/submissions',
        'POST /api/v1/resource-center/submissions/ticket/complete',
        'DELETE /api/v1/resource-center/submissions/ticket',
        'POST /api/v1/auth/revoke',
      ]),
    );
    for (final request in adapter.requests) {
      expect(
        request.headers['X-Student-ID'],
        '20260001',
        reason: request.uri.path,
      );
    }
  });

  test(
    'token refresh keeps the session student when the candidate changes',
    () async {
      await service.initialize();
      adapter.accessLifetime = Duration.zero;
      adapter.handler = (request) {
        if (request.uri.path == '/api/v1/auth/assertions') {
          service.updateLoginGate('20260002');
        }
        return null;
      };
      await login();
      await service.track('foreground');
      final refreshes = adapter.requests.where(
        (request) => request.uri.path == '/api/v1/auth/refresh',
      );
      expect(refreshes, isNotEmpty);
      for (final request in refreshes) {
        expect(request.headers['X-Student-ID'], '20260001');
      }
      expect(adapter.requests.last.headers['X-Student-ID'], '20260001');
      expect(
        adapter.requests.last.headers['Authorization'],
        'Bearer refreshed',
      );
    },
  );

  test('COS direct uploads do not disclose control identity headers', () async {
    final directory = await Directory.systemTemp.createTemp('control_upload_');
    addTearDown(() => directory.delete(recursive: true));
    final file = await File('${directory.path}/test.pdf').writeAsBytes([1]);
    adapter.handler = (_) => ResponseBody.fromString('', 200);
    await service.uploadToSignedUrl(
      'https://cos.example/file',
      filePath: file.path,
      sizeBytes: 1,
    );
    expect(adapter.requests.single.headers, isNot(contains('X-Student-ID')));
    expect(adapter.requests.single.headers, isNot(contains('Authorization')));
  });

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

  test('resource centre responses expose cache versions', () async {
    await service.initialize();
    await login();
    adapter.handler = (options) {
      switch (options.uri.path) {
        case '/api/v1/resource-center/courses':
          return _json({
            'version': 'c1.1700000000000:r1.1700000000001:t0.0:q0.0:tc1:qc0',
            'items': [
              {
                'code': 'C1',
                'name': '高等数学',
                'resource_count': 1,
                'version': 'r1.1700000000001:t0.0:c0',
              },
            ],
          });
        case '/api/v1/resources':
          return _json({
            'version': 'r1.1700000000001:t0.0:c0',
            'total': 1,
            'items': [
              {
                'id': 'res-1',
                'name': '期末试卷.pdf',
                'has_pdf': true,
                'updated_at': '2026-10-06T00:00:00.001Z',
              },
            ],
          });
        case '/api/v1/textbooks':
          return _json({
            'version': 'r1.1700000000001:t1.1700000000002:c0',
            'total': 0,
            'items': [],
          });
      }
      return null;
    };

    final center = await service.fetchResourceCourses();
    expect(center.version, startsWith('c1.'));
    expect(center.courses.single.version, 'r1.1700000000001:t0.0:c0');

    final resources = await service.fetchCourseResources('C1');
    expect(resources.version, center.courses.single.version);
    expect(resources.total, 1);
    expect(resources.items.single.updatedAt, '2026-10-06T00:00:00.001Z');

    final textbooks = await service.fetchCourseTextbooks('C1');
    expect(textbooks.version, 'r1.1700000000001:t1.1700000000002:c0');
  });

  test('a locked bank keeps its cached questions', () async {
    await service.initialize();
    await login();
    var locked = false;
    adapter.handler = (options) {
      if (options.uri.path == '/api/v1/question-banks') {
        return _json({
          'items': [
            {
              'id': 'QB-001',
              'name': '受保护题库',
              'requiresCDK': true,
              'updated_at': locked
                  ? '2026-10-06T00:00:00.002Z'
                  : '2026-10-06T00:00:00.001Z',
            },
          ],
          'total': 1,
          'hidden': [],
        });
      }
      if (options.uri.path == '/api/v1/question-banks/QB-001') {
        if (locked) return _error(403, 'question_bank_locked');
        return _json({
          'questionBank': {
            'id': 'QB-001',
            'name': '受保护题库',
            'requiresCDK': true,
            'questions': [
              {
                'questionNumber': 1,
                'type': '单选题',
                'title': '第1题',
                'questionText': '题干',
                'options': [
                  {'label': 'A', 'text': '选项 A'},
                ],
                'correctAnswer': 'A',
              },
            ],
          },
        });
      }
      return null;
    };

    final first = (await service.syncLearningQuestionBanks(const {})).single;
    expect(first.questions, hasLength(1));
    locked = true;
    final second = (await service.syncLearningQuestionBanks({first.id: first}))
        .single;
    expect(second.locked, isTrue);
    expect(second.questions, hasLength(1));
  });

  test('config version lookups are throttled until forced', () async {
    await service.initialize();
    await login();
    var requests = 0;
    adapter.handler = (options) {
      if (options.uri.path == '/api/v1/config/versions') {
        requests++;
        return _json({'schoolCalendar': 'v1', 'resourceCenter': 'r1'});
      }
      return null;
    };

    expect((await service.fetchConfigVersions()).resourceCenter, 'r1');
    expect((await service.fetchConfigVersions()).resourceCenter, 'r1');
    expect(requests, 1);
    expect(
      (await service.fetchConfigVersions(force: true)).resourceCenter,
      'r1',
    );
    expect(requests, 2);
  });

  test('signed resource URLs are reused until they expire', () async {
    await service.initialize();
    await login();
    var requests = 0;
    adapter.handler = (options) {
      if (options.uri.path == '/api/v1/resources/res-1/url') {
        requests++;
        return _json({
          'url': 'https://dl.xuda.live/papers/res-1.pdf?sign=a&t=1',
          'file_version': 'original',
          'expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 30))
              .toIso8601String(),
        });
      }
      return null;
    };

    final first = await service.fetchResourceURL(
      'res-1',
      fileVersion: 'original',
    );
    final second = await service.fetchResourceURL(
      'res-1',
      fileVersion: 'original',
    );
    expect(first, second);
    expect(requests, 1);
  });

  for (final textbook in [false, true]) {
    test(
      'replacement ${textbook ? 'textbook' : 'resource'} bypasses signed URL cache',
      () async {
        await service.initialize();
        await login();
        var version = 'original';
        var requests = 0;
        final path = textbook
            ? '/api/v1/textbooks/file-1/url'
            : '/api/v1/resources/file-1/url';
        adapter.handler = (options) {
          if (options.uri.path != path) return null;
          requests++;
          return _json({
            'url': 'https://dl.xuda.live/$version.pdf?sign=a',
            'file_version': version,
            'expires_at': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 30))
                .toIso8601String(),
          });
        };
        Future<String> fetch(String expected) => textbook
            ? service.fetchTextbookURL('file-1', fileVersion: expected)
            : service.fetchResourceURL('file-1', fileVersion: expected);

        expect(await fetch('original'), contains('/original.pdf'));
        version = 'replacement';
        expect(await fetch('replacement'), contains('/replacement.pdf'));
        expect(await fetch('replacement'), contains('/replacement.pdf'));
        expect(requests, 2);
      },
    );

    test(
      'stale ${textbook ? 'textbook' : 'resource'} metadata cannot download a replacement',
      () async {
        await service.initialize();
        await login();
        final path = textbook
            ? '/api/v1/textbooks/file-1/url'
            : '/api/v1/resources/file-1/url';
        adapter.handler = (options) => options.uri.path == path
            ? _json({
                'url': 'https://dl.xuda.live/new.pdf',
                'file_version': 'replacement',
                'expires_at': DateTime.now()
                    .toUtc()
                    .add(const Duration(minutes: 15))
                    .toIso8601String(),
              })
            : null;
        Future<String> fetch(String expected) => textbook
            ? service.fetchTextbookURL('file-1', fileVersion: expected)
            : service.fetchResourceURL('file-1', fileVersion: expected);

        await expectLater(
          fetch('original'),
          throwsA(
            isA<ControlApiException>().having(
              (e) => e.code,
              'code',
              'resource_changed',
            ),
          ),
        );
        expect(await fetch('replacement'), contains('/new.pdf'));
      },
    );
  }

  group('login gate', () {
    test('blocks all background communication while logged out', () async {
      service.updateLoginGate(null);
      final prefs = PreferencesStorage();
      await prefs.init();

      await service.initialize();
      await service.track('foreground');
      expect(await service.checkForUpdate(), isNull);
      expect(await service.refreshSchoolCalendarIfChanged(prefs), isFalse);
      await service.syncAfterOaLogin(
        studentId: '20260001',
        displayName: '测试用户',
      );

      expect(adapter.registrations, 0);
      expect(adapter.logins, 0);
    });

    test('reopens after login state is restored', () async {
      service.updateLoginGate(null);
      await service.track('foreground');
      expect(adapter.registrations, 0);

      service.updateLoginGate('20260001');
      await service.track('foreground');
      expect(adapter.registrations, 1);
    });

    test('treats blank student ids as logged out', () async {
      service.updateLoginGate('   ');
      await service.track('foreground');
      expect(adapter.registrations, 0);
    });
  });

  for (final globalRequestFails in [false, true]) {
    test(
      'a discovered college loads after an in-flight global calendar (fails=$globalRequestFails)',
      () async {
        final originalDays = semesterCalendar.days;
        final originalSlots = kTimeSlots;
        addTearDown(() {
          semesterCalendar.replaceDays(originalDays);
          semesterCalendar.replaceSlots(originalSlots);
        });
        final prefs = PreferencesStorage();
        await prefs.init();
        final requested = Completer<void>();
        final globalResponse = Completer<ResponseBody>();
        final colleges = <String?>[];
        final payload = {
          'days': [
            {'date': '2026-10-06', 'name': '', 'adjustment': ''},
          ],
          'slots': [
            {'index': 1, 'start': '09:00', 'end': '09:45', 'lab': false},
          ],
        };
        adapter.handler = (options) {
          if (options.uri.path == '/api/v1/config/versions') {
            return _json({'schoolCalendar': 'same-version'});
          }
          if (options.uri.path == '/api/v1/school-calendar') {
            final college = options.uri.queryParameters['college'];
            colleges.add(college);
            if (college == null) {
              requested.complete();
              return globalResponse.future;
            }
            return _json(payload);
          }
          return null;
        };
        final global = service.refreshSchoolCalendarIfChanged(prefs);
        final globalCheck = expectLater(
          global,
          globalRequestFails
              ? throwsA(isA<ControlApiException>())
              : completion(isTrue),
        );
        await requested.future;
        final scoped = service.refreshSchoolCalendarIfChanged(
          prefs,
          college: '信息工程学院',
        );
        globalResponse.complete(
          globalRequestFails ? _error(503, 'unavailable') : _json(payload),
        );
        await globalCheck;
        expect(await scoped, isTrue);
        expect(colleges, [null, '信息工程学院']);
        expect(prefs.getSchoolCalendarCollege(), '信息工程学院');
        expect(kTimeSlots.single.start, '09:00');
        await prefs.setCollegeName('信息工程学院');
        expect(await service.refreshSchoolCalendarIfChanged(prefs), isFalse);
        expect(colleges, hasLength(2));
      },
    );
  }

  test('calendar refresh detects updates within the same second', () async {
    final originalDays = semesterCalendar.days.toList();
    addTearDown(() => semesterCalendar.replaceDays(originalDays));
    final prefs = PreferencesStorage();
    await prefs.init();
    var revision = 1;
    var calendarRequests = 0;
    adapter.handler = (options) {
      if (options.uri.path == '/api/v1/config/versions') {
        return _json({'schoolCalendar': '2026-10-06T00:00:00.00${revision}Z'});
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
    expect(
      await service.refreshSchoolCalendarIfChanged(prefs, force: true),
      isTrue,
    );
    expect(semesterCalendar.days.single.name, '校历 2');
    expect(prefs.getSchoolCalendarVersion(), '2026-10-06T00:00:00.002Z');
    expect(await service.refreshSchoolCalendarIfChanged(prefs), isFalse);
    expect(calendarRequests, 2);
  });

  test('calendar refresh queues a notice when rules change', () async {
    final originalDays = semesterCalendar.days.toList();
    addTearDown(() {
      semesterCalendar.replaceDays(originalDays);
      semesterCalendar.setCalendarUpdateNotice(false);
    });
    final prefs = PreferencesStorage();
    await prefs.init();
    var revision = 1;
    adapter.handler = (options) {
      if (options.uri.path == '/api/v1/config/versions') {
        return _json({'schoolCalendar': '2026-10-06T00:00:00.00${revision}Z'});
      }
      if (options.uri.path == '/api/v1/school-calendar') {
        return _json({
          'days': [
            {
              'date': '2026-10-06',
              'name': '国庆',
              'adjustment': revision == 2 ? '/' : '',
            },
          ],
          'updatedAt': '2026-10-06T00:00:00.00${revision}Z',
        });
      }
      return null;
    };

    expect(await service.refreshSchoolCalendarIfChanged(prefs), isTrue);
    expect(semesterCalendar.calendarUpdateNotice, isFalse);

    revision = 2;
    expect(
      await service.refreshSchoolCalendarIfChanged(prefs, force: true),
      isTrue,
    );
    expect(semesterCalendar.calendarUpdateNotice, isTrue);
    expect(prefs.getSchoolCalendarUpdateNotice(), isTrue);

    semesterCalendar.setCalendarUpdateNotice(false);
    await prefs.setSchoolCalendarUpdateNotice(false);
    expect(await service.refreshSchoolCalendarIfChanged(prefs), isFalse);
    expect(semesterCalendar.calendarUpdateNotice, isFalse);

    revision = 3;
    expect(
      await service.refreshSchoolCalendarIfChanged(prefs, force: true),
      isTrue,
    );
    expect(semesterCalendar.calendarUpdateNotice, isTrue);
    expect(prefs.getSchoolCalendarUpdateNotice(), isTrue);
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
  final List<RequestOptions> requests = [];
  Duration accessLifetime = const Duration(minutes: 15);
  FutureOr<ResponseBody?> Function(RequestOptions)? handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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
              .add(accessLifetime)
              .toIso8601String(),
          'refresh_expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(days: 30))
              .toIso8601String(),
        }, 201);
      case '/api/v1/auth/refresh':
        return _json({
          'access_token': 'refreshed',
          'refresh_token': 'refresh_rotated',
          'expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 15))
              .toIso8601String(),
          'refresh_expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(days: 30))
              .toIso8601String(),
        });
      case '/api/v1/me':
        return _json({
          'user': {'display_name': '测试用户'},
        });
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
