import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import '../constants/network_config.dart';
import 'cas_service.dart';
import 'talker.dart';
import 'dio_factory.dart';

class JpTaskCourse {
  final String pjjgid;
  final String courseName;
  final String teacherName;
  final bool done;

  const JpTaskCourse({
    required this.pjjgid,
    required this.courseName,
    required this.teacherName,
    required this.done,
  });

  Map<String, dynamic> toJson() => {
    'pjjgid': pjjgid,
    'courseName': courseName,
    'teacherName': teacherName,
    'done': done,
  };

  factory JpTaskCourse.fromJson(Map<String, dynamic> json) => JpTaskCourse(
    pjjgid: json['pjjgid'] as String,
    courseName: json['courseName'] as String,
    teacherName: json['teacherName'] as String,
    done: json['done'] as bool,
  );
}

class JpTask {
  final String taskId;
  final String taskName;
  final String status;
  final String startTime;
  final String endTime;
  final int total;
  final int completed;
  final int pending;
  final List<JpTaskCourse> courses;

  const JpTask({
    required this.taskId,
    required this.taskName,
    required this.status,
    required this.startTime,
    required this.endTime,
    required this.total,
    required this.completed,
    required this.pending,
    required this.courses,
  });

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'taskName': taskName,
    'status': status,
    'startTime': startTime,
    'endTime': endTime,
    'total': total,
    'completed': completed,
    'pending': pending,
    'courses': courses.map((c) => c.toJson()).toList(),
  };

  factory JpTask.fromJson(Map<String, dynamic> json) => JpTask(
    taskId: json['taskId'] as String,
    taskName: json['taskName'] as String,
    status: json['status'] as String,
    startTime: json['startTime'] as String,
    endTime: json['endTime'] as String,
    total: json['total'] as int,
    completed: json['completed'] as int,
    pending: json['pending'] as int,
    courses: (json['courses'] as List)
        .map((c) => JpTaskCourse.fromJson(c as Map<String, dynamic>))
        .toList(),
  );
}

class JpStatusResult {
  final List<JpTask> tasks;
  const JpStatusResult({required this.tasks});

  Map<String, dynamic> toJson() => {
    'tasks': tasks.map((t) => t.toJson()).toList(),
  };

  factory JpStatusResult.fromJson(Map<String, dynamic> json) => JpStatusResult(
    tasks: (json['tasks'] as List)
        .map((t) => JpTask.fromJson(t as Map<String, dynamic>))
        .toList(),
  );
}

class JpAutoResult {
  final List<String> evaluated;
  final List<String> skipped;
  const JpAutoResult({required this.evaluated, required this.skipped});
}

class JpService {
  Future<String> _jpLogin(String username, String password) async {
    final cas = CasService();

    // REST path: get ST for AGG, skip CAS redirect chain
    final st = await cas.getServiceTicket(
      username,
      password,
      '$aggBaseUrl8080/loginSSO/',
    );
    if (st != null) {
      final dio = _createZlbzDio();
      try {
        return await _loginThroughAggregation(
          dio,
          '$aggBaseUrl8080/loginSSO/?ticket=$st',
          username,
        );
      } finally {
        dio.close(force: true);
      }
    }

    // Fallback: HTML CAS login with cookies
    final session = await cas.loginCas(username, password);
    final dio = session.dio;
    try {
      return await _loginThroughAggregation(
        dio,
        '$aggBaseUrl8080/loginSSO',
        username,
      );
    } finally {
      session.close();
    }
  }

  Dio _createZlbzDio() => DioFactory.createNaked(
    cookieJar: CookieJar(),
    connectTimeout: requestTimeout,
    receiveTimeout: requestTimeout,
  );

  Future<String> _loginThroughAggregation(
    Dio dio,
    String initialUrl,
    String username,
  ) async {
    final userCode = await _findAggregationUserCode(dio, initialUrl);

    // 8080's userCode is only an intermediate credential for the 8070
    // integration portal. That portal issues the encrypted code consumed by
    // the quality-platform backend.
    final sso = await dio.get<String>(
      '$aggBaseUrl8070/loginSSO',
      queryParameters: {'code': userCode},
      options: Options(
        responseType: ResponseType.plain,
        followRedirects: false,
        validateStatus: (s) => s != null && s < 400,
      ),
    );
    final authentication = _authenticationCookie(sso);
    if (authentication == null) throw AuthException('聚合平台登录失败');

    final encryptedResponse = await dio.post<dynamic>(
      '$aggBaseUrl8070/common/encrypt',
      data: {'userCode': username, 'role': '', 'url': ''},
      options: Options(
        headers: {'Authentication': authentication},
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    final encrypted = _encryptedCode(encryptedResponse.data);
    if (encrypted == null) throw AuthException('聚合平台登录失败');

    final quality = await dio.get<String>(
      '$zlbzBackendUrl/integration/loginSSO',
      queryParameters: {'code': encrypted},
      options: Options(
        responseType: ResponseType.plain,
        followRedirects: false,
        validateStatus: (s) => s != null && s < 400,
      ),
    );
    if (quality.statusCode != 302) {
      throw AuthException('质量平台登录失败');
    }
    final location = quality.headers.value('location');
    if (location == null || location.isEmpty) {
      throw AuthException('质量平台登录失败');
    }
    final login = _qualityLoginFromUrl(
      Uri.parse(zlbzBackendUrl).resolve(location),
    );
    if (login == null) throw AuthException('质量平台登录失败');

    final r = await dio.post(
      '$zlbzFrontendUrl/manage/integration/doLogin',
      queryParameters: {
        'loginname': login.$1,
        'roleName': login.$2,
        'response500': 'false',
      },
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    if (r.statusCode != 200) throw AuthException('质量平台登录失败');

    final data = r.data as Map<String, dynamic>?;
    final token = (data?['data'] as Map<String, dynamic>?)?['accessToken'];
    if (token is! String || token.isEmpty) {
      final message = data?['message'] ?? data?['msg'];
      throw AuthException(
        message is String && message.isNotEmpty ? message : '质量平台登录失败',
      );
    }
    return token;
  }

  /// Follows the aggregation SSO flow and extracts the intermediate code
  /// emitted by 8080. The code is exchanged through 8070 below.
  Future<String> _findAggregationUserCode(Dio dio, String initialUrl) async {
    var url = initialUrl;
    for (var i = 0; i < 12; i++) {
      final r = await dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (s) =>
              s != null && (s < 400 || s == 301 || s == 302 || s == 303),
        ),
      );

      final location = r.headers.value('location') ?? '';

      if (r.statusCode == 301 || r.statusCode == 302 || r.statusCode == 303) {
        if (location.isEmpty) break;
        url = Uri.parse(url).resolve(location).toString();
        continue;
      }

      final body = r.data ?? '';
      final userCode = RegExp(r'''var userCode = ['"]([^'"]+)['"]''')
          .firstMatch(body)
          ?.group(1);
      if (userCode != null && userCode.isNotEmpty) return userCode;
      break;
    }
    throw AuthException('聚合平台登录失败');
  }

  String? _authenticationCookie(Response<dynamic> response) {
    final headers = response.headers['set-cookie'] ?? const <String>[];
    for (final header in headers) {
      final match = RegExp(r'(?:^|[, ])Authentication=([^; ,]+)')
          .firstMatch(header);
      if (match != null) return match.group(1);
    }
    return null;
  }

  String? _encryptedCode(dynamic value) {
    dynamic body = value;
    if (body is String) {
      try {
        body = jsonDecode(body);
      } catch (_) {
        return null;
      }
    }
    if (body is! Map) return null;
    final code = body['data'];
    return code is String && code.isNotEmpty ? code : null;
  }

  (String, String)? _qualityLoginFromUrl(Uri uri) {
    if (uri.path != '/ymtzjcpg') return null;
    final loginname = uri.queryParameters['loginname'] ?? '';
    if (loginname.isEmpty) return null;
    return (loginname, uri.queryParameters['roleName'] ?? '');
  }

  // ── Query & Auto-evaluate ──

  Future<JpStatusResult> queryStatus(String username, String password) async {
    final token = await _jpLogin(username, password);
    final dio = _createZlbzDio();

    try {
      final (sfwc, tasks) = await _getTaskData(dio, token);
      if (tasks.isEmpty) return const JpStatusResult(tasks: []);

      final result = <JpTask>[];
      for (final task in tasks) {
        final taskId = '${task['taskid'] ?? ''}';
        final stat = sfwc[taskId] ?? <String, dynamic>{};
        final courses = await _getStudentCourses(dio, token, taskId);
        final pending = courses.where((c) => c['hassubmit'] != 1).length;
        final done = courses.where((c) => c['hassubmit'] == 1).length;

        result.add(
          JpTask(
            taskId: taskId,
            taskName: '${task['taskname'] ?? ''}',
            status: '${task['currentStatus'] ?? ''}',
            startTime: '${task['starttime'] ?? ''}',
            endTime: '${task['endtime'] ?? ''}',
            total: (stat['yprs'] as int?) ?? courses.length,
            completed: (stat['sprs'] as int?) ?? done,
            pending: (stat['wprs'] as int?) ?? pending,
            courses: courses
                .map(
                  (c) => JpTaskCourse(
                    pjjgid: '${c['pjjgid'] ?? ''}',
                    courseName: '${c['coursename'] ?? ''}',
                    teacherName: '${c['teachername'] ?? ''}',
                    done: c['hassubmit'] == 1,
                  ),
                )
                .toList(),
          ),
        );
      }
      return JpStatusResult(tasks: result);
    } finally {
      dio.close(force: true);
    }
  }

  Future<JpAutoResult> autoEvaluate(String username, String password) async {
    talker.info('[ACTION] 评教\n开始自动评教');

    final token = await _jpLogin(username, password);
    talker.info('[ACTION] 评教\n登录成功, token长度=${token.length}');

    final dio = _createZlbzDio();
    try {
      final (_, tasks) = await _getTaskData(dio, token);
      talker.info(
        '[ACTION] 评教\n获取到 ${tasks.length} 个任务: '
        '${tasks.map((t) => '${t['taskname']}[${t['currentStatus']}]').join(', ')}',
      );
      if (tasks.isEmpty) throw AuthException('没有评教任务');

      var active = tasks.where((t) => t['currentStatus'] == '进行中').toList();
      if (active.isEmpty) {
        talker.info('[ACTION] 评教\n无进行中任务, 使用全部任务');
        active = tasks;
      } else {
        talker.info('[ACTION] 评教\n筛选到 ${active.length} 个进行中任务');
      }

      final evaluated = <String>[];
      final skipped = <String>[];

      for (final task in active) {
        final taskId = '${task['taskid'] ?? ''}';
        final indexId = '${task['indexid'] ?? ''}';
        talker.info(
          '[ACTION] 评教\n处理任务: ${task['taskname']}, '
          'taskId=$taskId, indexId=$indexId',
        );

        final courses = await _getStudentCourses(dio, token, taskId);
        talker.info('[ACTION] 评教\n任务 $taskId 获取到 ${courses.length} 门课程');

        for (final course in courses) {
          final label =
              '${course['coursename'] ?? ''}(${course['teachername'] ?? ''})';
          final hassubmit = course['hassubmit'];
          final zt = course['zt'];
          talker.info(
            '[ACTION] 评教\n课程: $label, '
            'hassubmit=$hassubmit(${hassubmit.runtimeType}), zt=$zt',
          );

          if (course['hassubmit'] == 1 || course['zt'] == 'yjs') {
            skipped.add(label);
            talker.info('[ACTION] 评教\n跳过(已提交): $label');
            continue;
          }

          final pjcoursetype = '${course['pjcoursetype'] ?? ''}';
          talker.info(
            '[ACTION] 评教\n获取指标体系: '
            'indexId=$indexId, pjcoursetype=$pjcoursetype',
          );
          final indexTree = await _getIndexSystem(
            dio,
            token,
            indexId,
            pjcoursetype,
          );
          if (indexTree.isEmpty) {
            skipped.add('$label(无指标)');
            talker.error('评教\n跳过(无指标体系): $label');
            continue;
          }

          final indicators = _flattenIndicators(indexTree);
          talker.info('[ACTION] 评教\n展开指标: ${indicators.length} 个叶子节点');
          if (indicators.isEmpty) {
            skipped.add('$label(指标为空)');
            talker.error('评教\n跳过(指标为空): $label');
            continue;
          }

          final (ok, serverMsg) = await _submitEvaluation(
            dio,
            token,
            task,
            course,
            indicators,
          );
          final submitMessage =
              '评教\n提交${ok ? '成功' : '失败'}: $label'
              '${serverMsg != null ? ' ($serverMsg)' : ''}';
          if (ok) {
            talker.info('[ACTION] $submitMessage');
          } else {
            talker.error(submitMessage);
          }
          if (ok) {
            evaluated.add(label);
          } else {
            skipped.add('$label(提交失败)');
            if (serverMsg != null) {
              throw Exception(serverMsg);
            }
          }
        }
      }

      talker.info(
        '[ACTION] 评教\n完成: 已评=${evaluated.length}, 跳过=${skipped.length}',
      );
      return JpAutoResult(evaluated: evaluated, skipped: skipped);
    } finally {
      dio.close(force: true);
    }
  }

  // ── API helpers ──

  Future<Response> _apiPost(
    Dio dio,
    String token,
    String path, {
    Map<String, dynamic>? queryParams,
    dynamic data,
    bool jsonBody = false,
  }) {
    final headers = <String, String>{
      'Authorization': 'Bearer$token',
      'Referer': '$zlbzFrontendUrl/',
    };
    if (jsonBody) headers['Content-Type'] = 'application/json;charset=utf-8';

    return dio.post(
      '$zlbzFrontendUrl/api$path',
      queryParameters: queryParams,
      data: data,
      options: Options(
        headers: headers,
        validateStatus: (s) => s != null && s < 500,
      ),
    );
  }

  Future<(Map<String, Map<String, dynamic>>, List<Map<String, dynamic>>)>
  _getTaskData(Dio dio, String token) async {
    final r = await _apiPost(
      dio,
      token,
      '/xspj/xspj/getXspjtask',
      queryParams: {},
    );
    talker.debug('[NET] 评教API\ngetXspjtask status=${r.statusCode}');
    if (r.statusCode != 200) {
      return (<String, Map<String, dynamic>>{}, <Map<String, dynamic>>[]);
    }
    final body = r.data as Map<String, dynamic>?;
    talker.debug(
      '[NET] 评教API\ngetXspjtask code=${body?['code']}, '
      'msg=${body?['msg'] ?? ''}',
    );
    if (body == null || body['code'] != 200) {
      return (<String, Map<String, dynamic>>{}, <Map<String, dynamic>>[]);
    }
    final data = (body['data'] as Map<String, dynamic>?) ?? {};
    final sfwcList = (data['taskSfwc'] as List?) ?? [];
    final sfwc = <String, Map<String, dynamic>>{};
    for (final s in sfwcList) {
      sfwc['${(s as Map<String, dynamic>)['taskid'] ?? ''}'] = s;
    }
    final tasks = ((data['pageData'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
    return (sfwc, tasks);
  }

  Future<List<Map<String, dynamic>>> _getStudentCourses(
    Dio dio,
    String token,
    String taskId,
  ) async {
    final r = await _apiPost(
      dio,
      token,
      '/xspj/xspj/getXspjStudentCourses',
      queryParams: {'taskid': taskId},
    );
    talker.debug(
      '[NET] 评教API\ngetStudentCourses($taskId) status=${r.statusCode}',
    );
    if (r.statusCode != 200) return [];
    final body = r.data as Map<String, dynamic>?;
    talker.debug(
      '[NET] 评教API\ngetStudentCourses code=${body?['code']}, '
      'msg=${body?['msg'] ?? ''}',
    );
    if (body == null || body['code'] != 200) return [];
    final list =
        ((body['data'] as Map<String, dynamic>?)?['pageData'] as List? ?? [])
            .cast<Map<String, dynamic>>();
    talker.debug('[NET] 评教API\ngetStudentCourses 返回 ${list.length} 门课');
    return list;
  }

  Future<List<Map<String, dynamic>>> _getIndexSystem(
    Dio dio,
    String token,
    String indexId,
    String pjcoursetype,
  ) async {
    final r = await _apiPost(
      dio,
      token,
      '/xspj/xspj/getXspjTindexSystem',
      queryParams: {'indexid': indexId, 'pjcoursetype': pjcoursetype},
    );
    talker.debug(
      '[NET] 评教API\ngetIndexSystem($indexId, $pjcoursetype) '
      'status=${r.statusCode}',
    );
    if (r.statusCode != 200) return [];
    final body = r.data as Map<String, dynamic>?;
    talker.debug(
      '[NET] 评教API\ngetIndexSystem code=${body?['code']}, '
      'msg=${body?['msg'] ?? ''}',
    );
    if (body == null || body['code'] != 200) return [];
    final list =
        ((body['data'] as Map<String, dynamic>?)?['pageData'] as List? ?? [])
            .cast<Map<String, dynamic>>();
    talker.debug('[NET] 评教API\ngetIndexSystem 返回 ${list.length} 个指标节点');
    return list;
  }

  List<Map<String, dynamic>> _flattenIndicators(
    List<Map<String, dynamic>> tree,
  ) {
    final flat = <Map<String, dynamic>>[];
    for (final node in tree) {
      final sub = (node['subList'] as List?)?.cast<Map<String, dynamic>>();
      if (sub != null && sub.isNotEmpty) {
        flat.addAll(_flattenIndicators(sub));
      } else {
        flat.add(node);
      }
    }
    return flat;
  }

  (List<Map<String, dynamic>>, double) _buildEvaluateResult(
    List<Map<String, dynamic>> indicators,
  ) {
    final results = <Map<String, dynamic>>[];
    var totalScore = 0.0;

    for (var idx = 0; idx < indicators.length; idx++) {
      final ind = indicators[idx];
      final itemType = '${ind['type'] ?? ''}';
      final isScored = ind['isscoredid'] == 1 || ind['isscored'] == '是';
      final options =
          (ind['optionarr'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      final result = <String, dynamic>{
        'indexid': ind['indexid'] ?? '',
        'index_order': ind['ordor'] ?? idx + 1,
        'sfbt': ind['isemptyed'] ?? '否',
        'index_type': itemType,
      };
      if (ind['firstlevlindex'] != null) {
        result['yjzb'] = ind['firstlevlindex'];
      }

      if ((itemType == '单选题' || itemType == '量表题') && options.isNotEmpty) {
        final best = _maxScoreOption(options);
        final score = double.tryParse('${best['score'] ?? 0}') ?? 0;
        result['index_title'] = best['title'] ?? '';
        result['index_score'] = score;
        result['option_id'] = best['id'] ?? 0;
        if (isScored) totalScore += score;
      } else if (itemType == '打分题') {
        final maxScore =
            (double.tryParse('${ind['score'] ?? 0}') ?? 0) *
            (double.tryParse('${ind['weight'] ?? 1}') ?? 1);
        result['index_title'] = maxScore == maxScore.toInt()
            ? '${maxScore.toInt()}'
            : '$maxScore';
        result['index_score'] = maxScore;
        if (isScored) totalScore += maxScore;
      } else if (itemType == '问答题' || itemType == '填空题') {
        result['index_title'] = '';
        result['index_score'] = 0;
      } else if (itemType == '多选题' && options.isNotEmpty) {
        result['index_title'] = options.map((o) => o['title'] ?? '').join('*');
        result['index_score'] = 0;
      } else if (options.isNotEmpty) {
        final best = _maxScoreOption(options);
        final score = double.tryParse('${best['score'] ?? 0}') ?? 0;
        result['index_title'] = best['title'] ?? '';
        result['index_score'] = score;
        result['option_id'] = best['id'] ?? 0;
        if (isScored) totalScore += score;
      } else {
        result['index_title'] = '';
        result['index_score'] = 0;
      }
      results.add(result);
    }

    return (results, double.parse(totalScore.toStringAsFixed(2)));
  }

  Map<String, dynamic> _maxScoreOption(List<Map<String, dynamic>> options) {
    return options.reduce((a, b) {
      final sa = double.tryParse('${a['score'] ?? 0}') ?? 0;
      final sb = double.tryParse('${b['score'] ?? 0}') ?? 0;
      return sa >= sb ? a : b;
    });
  }

  Future<(bool, String?)> _submitEvaluation(
    Dio dio,
    String token,
    Map<String, dynamic> task,
    Map<String, dynamic> course,
    List<Map<String, dynamic>> indicators,
  ) async {
    final (evalResults, totalScore) = _buildEvaluateResult(indicators);
    final now = DateTime.now();
    final commitTime =
        '${now.year}-${_pad(now.month)}-${_pad(now.day)} '
        '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}';

    final payload = <String, dynamic>{
      'classno': course['classno'] ?? '',
      'coursecode': course['coursecode'] ?? '',
      'coursename': course['coursename'] ?? '',
      'jobnumber': course['jobnumber'] ?? '',
      'studentid': course['studentid'] ?? '',
      'studentname': course['studentname'] ?? '',
      'taskid': task['taskid'] ?? '',
      'teachername': course['teachername'] ?? '',
      'yearterm': course['yearterm'] ?? '',
      'totalscore': totalScore,
      'pjcoursetype': course['pjcoursetype'] ?? '',
      'courseorgcode': course['courseorgcode'] ?? '',
      'courseorgname': course['courseorgname'] ?? '',
      'evaluateResult': evalResults,
      'commit_time': commitTime,
    };
    if (course['pjjgid'] != null) {
      payload['tevaluateResultid'] = course['pjjgid'];
    }

    talker.debug(
      '[NET] 评教API\nsubmitEvaluation: ${course['coursename']}, '
      'totalScore=$totalScore, evalResults=${evalResults.length}项',
    );

    final r = await _apiPost(
      dio,
      token,
      '/xspj/xspj/saveStudentComment',
      queryParams: {},
      data: jsonEncode([payload]),
      jsonBody: true,
    );

    final body = r.data as Map<String, dynamic>?;
    final code = body?['code'];
    final msg = (body?['message'] ?? body?['msg'] ?? '') as String;
    talker.debug(
      '[NET] 评教API\nsubmitEvaluation status=${r.statusCode}, '
      'code=$code, msg=$msg',
    );
    if (r.statusCode != 200) return (false, 'HTTP ${r.statusCode}');
    if (code == 200) return (true, null);
    return (false, msg.isNotEmpty ? msg : '服务器错误($code)');
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
