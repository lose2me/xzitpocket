import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:pointycastle/export.dart';

import '../constants/network_config.dart';
import 'cas_service.dart';

const _aggPublicKeyB64 =
    'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDBKw11ggtOzD1XfvcicMM3EIUg'
    'lOuOrEDiE7so9f9TogYvchS8FoxOrqW0520GwDrZLP5tc/DXo0lETPgZyW5RNhu4'
    '4NGqEo37iAbfdnDyFYzQw48WnxhsvHcbeO/Ni+wNnjG8PMtVX2xt0yTBZz/MUTeN'
    'U7pEe6Rr4LxPDCWC5QIDAQAB';

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
}

class JpStatusResult {
  final List<JpTask> tasks;
  const JpStatusResult({required this.tasks});
}

class JpAutoResult {
  final List<String> evaluated;
  final List<String> skipped;
  const JpAutoResult({required this.evaluated, required this.skipped});
}

class JpService {
  Future<String> _jpLogin(String username, String password) async {
    final session = await CasService().loginCas(username, password);
    final dio = session.dio;

    try {
      await _ssoToAggregation(dio);
      return await _ssoToZlbz4(username);
    } finally {
      session.close();
    }
  }

  Future<void> _ssoToAggregation(Dio dio) async {
    final r = await followRedirectsManually(dio, '$aggBaseUrl8080/loginSSO');
    if (r.statusCode != 200) throw AuthException('聚合平台登录失败');

    final m = RegExp(r"var userCode = '([^']+)'").firstMatch(r.data ?? '');
    if (m == null) throw AuthException('聚合平台登录失败');

    final r2 = await followRedirectsManually(
      dio,
      '$aggBaseUrl8070/loginSSO?code=${Uri.encodeComponent(m.group(1)!)}',
    );
    if (r2.statusCode != 200) throw AuthException('聚合平台登录失败');
  }

  Future<String> _ssoToZlbz4(String username) async {
    final payload = jsonEncode({
      'userCode': username,
      'role': 'ROLE_STUDENT',
      'url': '',
    });
    final encryptedCode = _pkcs1Encrypt(payload, _aggPublicKeyB64);

    final dio = Dio(BaseOptions(
      connectTimeout: requestTimeout,
      receiveTimeout: requestTimeout,
    ));
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (_, __, ___) => true;
        return client;
      },
    );

    try {
      final r = await dio.get(
        '$zlbzBackendUrl/integration/loginSSO',
        queryParameters: {'code': encryptedCode},
        options: Options(
          followRedirects: false,
          validateStatus: (s) => s != null && (s < 400 || s == 302),
        ),
      );
      if (r.statusCode != 302) throw AuthException('质量平台登录失败');

      final location = r.headers.value('location') ?? '';
      if (!location.contains('?')) throw AuthException('质量平台登录失败');

      final query = Uri.parse(location).queryParameters;
      final loginname = query['loginname'] ?? '';
      final roleName = query['roleName'] ?? '';
      if (loginname.isEmpty || roleName.isEmpty) {
        throw AuthException('质量平台登录失败');
      }

      final r2 = await dio.post(
        '$zlbzFrontendUrl/manage/integration/doLogin'
        '?loginname=$loginname&roleName=$roleName&response500=false',
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      if (r2.statusCode != 200) throw AuthException('质量平台登录失败');

      final data = r2.data as Map<String, dynamic>;
      final token =
          (data['data'] as Map<String, dynamic>?)?['accessToken'] as String?;
      if (token == null) throw AuthException('质量平台登录失败');
      return token;
    } finally {
      dio.close(force: true);
    }
  }

  // ── Query & Auto-evaluate ──

  Future<JpStatusResult> queryStatus(String username, String password) async {
    final token = await _jpLogin(username, password);

    final (sfwc, tasks) = await _getTaskData(token);
    if (tasks.isEmpty) return const JpStatusResult(tasks: []);

    final result = <JpTask>[];
    for (final task in tasks) {
      final taskId = '${task['taskid'] ?? ''}';
      final stat = sfwc[taskId] ?? <String, dynamic>{};
      final courses = await _getStudentCourses(token, taskId);
      final pending = courses.where((c) => c['hassubmit'] != 1).length;
      final done = courses.where((c) => c['hassubmit'] == 1).length;

      result.add(JpTask(
        taskId: taskId,
        taskName: '${task['taskname'] ?? ''}',
        status: '${task['currentStatus'] ?? ''}',
        startTime: '${task['starttime'] ?? ''}',
        endTime: '${task['endtime'] ?? ''}',
        total: (stat['yprs'] as int?) ?? courses.length,
        completed: (stat['sprs'] as int?) ?? done,
        pending: (stat['wprs'] as int?) ?? pending,
        courses: courses
            .map((c) => JpTaskCourse(
                  pjjgid: '${c['pjjgid'] ?? ''}',
                  courseName: '${c['coursename'] ?? ''}',
                  teacherName: '${c['teachername'] ?? ''}',
                  done: c['hassubmit'] == 1,
                ))
            .toList(),
      ));
    }
    return JpStatusResult(tasks: result);
  }

  Future<JpAutoResult> autoEvaluate(String username, String password) async {
    final token = await _jpLogin(username, password);
    final tasks = await _getTaskList(token);
    if (tasks.isEmpty) throw AuthException('没有评教任务');

    var active = tasks.where((t) => t['currentStatus'] == '进行中').toList();
    if (active.isEmpty) active = tasks;

    final evaluated = <String>[];
    final skipped = <String>[];

    for (final task in active) {
      final taskId = '${task['taskid'] ?? ''}';
      final indexId = '${task['indexid'] ?? ''}';
      final courses = await _getStudentCourses(token, taskId);

      for (final course in courses) {
        final label =
            '${course['coursename'] ?? ''}(${course['teachername'] ?? ''})';

        if (course['hassubmit'] == 1 || course['zt'] == 'yjs') {
          skipped.add(label);
          continue;
        }

        final pjcoursetype = '${course['pjcoursetype'] ?? ''}';
        final indexTree = await _getIndexSystem(token, indexId, pjcoursetype);
        if (indexTree.isEmpty) {
          skipped.add('$label(无指标)');
          continue;
        }

        final indicators = _flattenIndicators(indexTree);
        if (indicators.isEmpty) {
          skipped.add('$label(指标为空)');
          continue;
        }

        final ok = await _submitEvaluation(token, task, course, indicators);
        (ok ? evaluated : skipped).add(ok ? label : '$label(提交失败)');
      }
    }

    return JpAutoResult(evaluated: evaluated, skipped: skipped);
  }

  // ── API helpers ──

  Future<Response> _apiPost(
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

    final dio = Dio(BaseOptions(
      connectTimeout: requestTimeout,
      receiveTimeout: requestTimeout,
    ));
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (_, __, ___) => true;
        return client;
      },
    );

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
      _getTaskData(String token) async {
    final r = await _apiPost(token, '/xspj/xspj/getXspjtask', queryParams: {});
    if (r.statusCode != 200) return (<String, Map<String, dynamic>>{}, <Map<String, dynamic>>[]);
    final body = r.data as Map<String, dynamic>?;
    if (body == null || body['code'] != 200) return (<String, Map<String, dynamic>>{}, <Map<String, dynamic>>[]);
    final data = (body['data'] as Map<String, dynamic>?) ?? {};
    final sfwcList = (data['taskSfwc'] as List?) ?? [];
    final sfwc = <String, Map<String, dynamic>>{};
    for (final s in sfwcList) {
      sfwc['${(s as Map<String, dynamic>)['taskid'] ?? ''}'] = s;
    }
    final tasks = ((data['pageData'] as List?) ?? []).cast<Map<String, dynamic>>();
    return (sfwc, tasks);
  }

  Future<List<Map<String, dynamic>>> _getTaskList(String token) async {
    final (_, tasks) = await _getTaskData(token);
    return tasks;
  }

  Future<List<Map<String, dynamic>>> _getStudentCourses(
    String token,
    String taskId,
  ) async {
    final r = await _apiPost(
      token,
      '/xspj/xspj/getXspjStudentCourses',
      queryParams: {'taskid': taskId},
    );
    if (r.statusCode != 200) return [];
    final body = r.data as Map<String, dynamic>?;
    if (body == null || body['code'] != 200) return [];
    return ((body['data'] as Map<String, dynamic>?)?['pageData'] as List? ?? [])
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _getIndexSystem(
    String token,
    String indexId,
    String pjcoursetype,
  ) async {
    final r = await _apiPost(
      token,
      '/xspj/xspj/getXspjTindexSystem',
      queryParams: {'indexid': indexId, 'pjcoursetype': pjcoursetype},
    );
    if (r.statusCode != 200) return [];
    final body = r.data as Map<String, dynamic>?;
    if (body == null || body['code'] != 200) return [];
    return ((body['data'] as Map<String, dynamic>?)?['pageData'] as List? ?? [])
        .cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> _flattenIndicators(List<Map<String, dynamic>> tree) {
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
        final maxScore = (double.tryParse('${ind['score'] ?? 0}') ?? 0) *
            (double.tryParse('${ind['weight'] ?? 1}') ?? 1);
        result['index_title'] =
            maxScore == maxScore.toInt() ? '${maxScore.toInt()}' : '$maxScore';
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

  Future<bool> _submitEvaluation(
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
    if (course['pjjgid'] != null) payload['tevaluateResultid'] = course['pjjgid'];

    final r = await _apiPost(
      token,
      '/xspj/xspj/saveStudentComment',
      queryParams: {},
      data: jsonEncode([payload]),
      jsonBody: true,
    );
    if (r.statusCode != 200) return false;
    return (r.data as Map<String, dynamic>?)?['code'] == 200;
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static String _pkcs1Encrypt(String plaintext, String pubkeyB64) {
    final derBytes = base64.decode(pubkeyB64);
    final publicKey = _parsePublicKeyFromDer(derBytes);

    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    final secureRandom = FortunaRandom()
      ..seed(KeyParameter(Uint8List.fromList(seeds)));

    final encryptor = PKCS1Encoding(RSAEngine())
      ..init(
        true,
        ParametersWithRandom(
          PublicKeyParameter<RSAPublicKey>(publicKey),
          secureRandom,
        ),
      );

    final inputBytes = utf8.encode(plaintext);
    final keySize = publicKey.modulus!.bitLength ~/ 8;
    final maxChunk = keySize - 11;
    final chunks = <int>[];

    for (var i = 0; i < inputBytes.length; i += maxChunk) {
      final end =
          (i + maxChunk > inputBytes.length) ? inputBytes.length : i + maxChunk;
      final block = Uint8List.fromList(inputBytes.sublist(i, end));
      chunks.addAll(encryptor.process(block));
    }

    return base64.encode(chunks);
  }

  static RSAPublicKey _parsePublicKeyFromDer(Uint8List der) {
    int offset = 0;

    (int tag, int length, int headerLen) readTlv(int pos) {
      final tag = der[pos];
      pos++;
      int length = der[pos];
      pos++;
      int headerLen = 2;
      if (length & 0x80 != 0) {
        final numBytes = length & 0x7f;
        length = 0;
        for (var i = 0; i < numBytes; i++) {
          length = (length << 8) | der[pos];
          pos++;
          headerLen++;
        }
      }
      return (tag, length, headerLen);
    }

    BigInt readInteger(int pos) {
      final (_, len, hLen) = readTlv(pos);
      final start = pos + hLen;
      final bytes = der.sublist(start, start + len);
      final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      return BigInt.parse(hex, radix: 16);
    }

    // Outer SEQUENCE
    var (_, _, hLen) = readTlv(offset);
    offset += hLen;

    // AlgorithmIdentifier SEQUENCE - skip it
    var (_, algLen, algHLen) = readTlv(offset);
    offset += algHLen + algLen;

    // BIT STRING
    var (_, _, bsHLen) = readTlv(offset);
    offset += bsHLen;
    offset++; // skip unused bits byte

    // Inner SEQUENCE (RSAPublicKey)
    var (_, _, innerHLen) = readTlv(offset);
    offset += innerHLen;

    // Modulus INTEGER
    final modulus = readInteger(offset);
    final (_, modLen, modHLen) = readTlv(offset);
    offset += modHLen + modLen;

    // Exponent INTEGER
    final exponent = readInteger(offset);

    return RSAPublicKey(modulus, exponent);
  }
}
