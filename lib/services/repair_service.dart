import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;

import '../constants/network_config.dart';
import 'cas_service.dart';
import 'dio_factory.dart';
import 'talker.dart';

class RepairArea {
  final String id;
  final String name;

  const RepairArea({required this.id, required this.name});

  factory RepairArea.fromJson(Map<String, dynamic> json) => RepairArea(
    id: '${json['areauuid'] ?? ''}',
    name: '${json['areaname'] ?? ''}',
  );
}

class RepairItem {
  final String id;
  final String name;

  const RepairItem({required this.id, required this.name});

  factory RepairItem.fromJson(Map<String, dynamic> json) => RepairItem(
    id: '${json['itemuuid'] ?? ''}',
    name: '${json['itemname'] ?? ''}',
  );
}

class RepairUserInfo {
  final String username;
  final String phone;

  const RepairUserInfo({required this.username, required this.phone});

  Map<String, dynamic> toJson() => {'username': username, 'phone': phone};

  factory RepairUserInfo.fromJson(Map<String, dynamic> json) => RepairUserInfo(
    username: json['username'] as String,
    phone: json['phone'] as String,
  );
}

class RepairRecord {
  /// Internal form UUID required by getRepairFormById. This is different
  /// from [orderId], which is the human-readable repair number.
  final String formUuid;
  final String orderId;
  final String content;
  final String areaName;
  final String itemName;
  final String address;
  final String status;
  final String createTime;

  const RepairRecord({
    this.formUuid = '',
    required this.orderId,
    required this.content,
    required this.areaName,
    required this.itemName,
    required this.address,
    required this.status,
    required this.createTime,
  });

  factory RepairRecord.fromJson(Map<String, dynamic> json) => RepairRecord(
    formUuid: '${json['uuid'] ?? json['formuuid'] ?? json['formUuid'] ?? ''}',
    orderId: '${json['orderid'] ?? json['orderId'] ?? ''}',
    content: '${json['content'] ?? ''}',
    areaName: '${json['areaname'] ?? json['areaName'] ?? ''}',
    itemName: '${json['itemname'] ?? json['itemName'] ?? ''}',
    address: '${json['address'] ?? ''}',
    status: '${json['nodename'] ?? json['status'] ?? '未知'}',
    createTime: '${json['createtime'] ?? json['createTime'] ?? ''}',
  );

  Map<String, dynamic> toJson() => {
    'formUuid': formUuid,
    'orderId': orderId,
    'content': content,
    'areaName': areaName,
    'itemName': itemName,
    'address': address,
    'status': status,
    'createTime': createTime,
  };
}

class RepairAttachment {
  final String url;
  final String thumbnailUrl;

  const RepairAttachment({required this.url, required this.thumbnailUrl});

  factory RepairAttachment.fromJson(Map<String, dynamic> json) {
    final url = '${json['lookpath'] ?? json['url'] ?? json['imgurl'] ?? ''}';
    final path = '${json['imgurl'] ?? ''}';
    return RepairAttachment(url: url, thumbnailUrl: path);
  }
}

class RepairProcessStep {
  final String name;
  final String time;
  final String operatorName;
  final String note;
  final bool current;
  final List<RepairAttachment> attachments;

  const RepairProcessStep({
    required this.name,
    required this.time,
    required this.operatorName,
    required this.note,
    required this.current,
    this.attachments = const [],
  });
}

class RepairDetail {
  final String formUuid;
  final String orderId;
  final String content;
  final String areaName;
  final String itemName;
  final String address;
  final String status;
  final String createTime;
  final String acceptTime;
  final String repairer;
  final String teamName;
  final String repairUnit;
  final String remark;
  final String result;
  final List<RepairAttachment> attachments;
  final List<RepairProcessStep> steps;
  final Map<String, dynamic> raw;

  const RepairDetail({
    required this.formUuid,
    required this.orderId,
    required this.content,
    required this.areaName,
    required this.itemName,
    required this.address,
    required this.status,
    required this.createTime,
    required this.acceptTime,
    required this.repairer,
    required this.teamName,
    required this.repairUnit,
    required this.remark,
    required this.result,
    required this.attachments,
    required this.steps,
    required this.raw,
  });

  factory RepairDetail.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? raw,
  }) {
    final current =
        '${json['nodename'] ?? json['orderstatus'] ?? json['status'] ?? ''}';
    final createTime = '${json['createtime'] ?? json['createTime'] ?? ''}';
    final acceptTime = '${json['jdrq'] ?? json['accepttime'] ?? ''}';
    final attachments =
        (json['imgs'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(RepairAttachment.fromJson)
            .toList() ??
        const <RepairAttachment>[];

    final steps = <RepairProcessStep>[];
    final rawFlow =
        <dynamic>[
              json['process'],
              json['processList'],
              json['processlist'],
              json['flow'],
              json['flowList'],
              json['nodelist'],
            ]
            .whereType<List>()
            .expand((value) => value)
            .whereType<Map<String, dynamic>>()
            .toList();
    for (var index = 0; index < rawFlow.length; index++) {
      final node = rawFlow[index];
      final name =
          '${node['nodename'] ?? node['nodeName'] ?? node['name'] ?? node['status'] ?? ''}';
      if (name.trim().isEmpty) continue;
      final rawOperator =
          '${node['operatorname'] ?? node['operator'] ?? node['operatorName'] ?? node['username'] ?? node['maintainer'] ?? ''}';
      final operatorName =
          rawOperator == '${json['creater'] ?? ''}' &&
              '${json['username'] ?? ''}'.isNotEmpty
          ? '${json['username']}'
          : rawOperator;
      final nodeAttachments = <RepairAttachment>[];
      for (final image in (node['imgs'] as List? ?? const [])) {
        if (image is Map<String, dynamic>) {
          nodeAttachments.add(RepairAttachment.fromJson(image));
        }
      }
      steps.add(
        RepairProcessStep(
          name: name,
          time:
              '${node['time'] ?? node['operatetime'] ?? node['operateTime'] ?? node['createtime'] ?? ''}',
          operatorName: operatorName,
          note:
              '${node['nodecontent'] ?? node['remark'] ?? node['comment'] ?? node['content'] ?? ''}',
          current:
              node['current'] == true ||
              node['iscurrent'] == true ||
              index == rawFlow.length - 1,
          attachments: nodeAttachments,
        ),
      );
    }
    if (steps.isEmpty) {
      // The production endpoint currently returns the form plus its current
      // node, while older deployments may include the full workflow array.
      // Use only milestones backed by fields present in that response.
      if (createTime.isNotEmpty) {
        steps.add(
          RepairProcessStep(
            name: '提交报修',
            time: createTime,
            operatorName: '${json['creater'] ?? json['username'] ?? ''}',
            note: '${json['content'] ?? ''}',
            current: false,
            attachments: const [],
          ),
        );
      }
      if (acceptTime.isNotEmpty) {
        steps.add(
          RepairProcessStep(
            name: '已接单',
            time: acceptTime,
            operatorName: '${json['repairer'] ?? json['maintainer'] ?? ''}',
            note: '${json['teamname'] ?? json['maintainunit'] ?? ''}',
            current: false,
            attachments: const [],
          ),
        );
      }
      if (current.isNotEmpty) {
        steps.add(
          RepairProcessStep(
            name: current,
            time: '${json['finishTime'] ?? json['completiontime'] ?? ''}',
            operatorName: '${json['username'] ?? json['maintainer'] ?? ''}',
            note:
                '${json['rvcontent'] ?? json['ysyj'] ?? json['remark'] ?? ''}',
            current: true,
            attachments: attachments,
          ),
        );
      }
    }
    steps.sort((a, b) {
      final aTime = _repairStepDate(a.time);
      final bTime = _repairStepDate(b.time);
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return RepairDetail(
      formUuid: '${json['uuid'] ?? json['formuuid'] ?? ''}',
      orderId: '${json['orderid'] ?? json['orderId'] ?? ''}',
      content: '${json['content'] ?? ''}',
      areaName: '${json['areaname'] ?? json['areaName'] ?? ''}',
      itemName: '${json['itemname'] ?? json['itemName'] ?? ''}',
      address: '${json['address'] ?? ''}',
      status: current,
      createTime: createTime,
      acceptTime: acceptTime,
      repairer: '${json['repairer'] ?? json['maintainer'] ?? ''}',
      teamName: '${json['teamname'] ?? json['maintainunit'] ?? ''}',
      repairUnit: '${json['maintainunit'] ?? json['bussinessmanname'] ?? ''}',
      remark: '${json['remark'] ?? ''}',
      result: '${json['rvcontent'] ?? json['ysyj'] ?? ''}',
      attachments: attachments,
      steps: steps,
      raw: raw ?? json,
    );
  }

  static DateTime? _repairStepDate(String value) {
    final normalized = value.trim().replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized);
  }
}

class RepairResult {
  final RepairUserInfo userInfo;
  final List<RepairRecord> records;

  const RepairResult({required this.userInfo, required this.records});

  Map<String, dynamic> toJson() => {
    'userInfo': userInfo.toJson(),
    'records': records.map((r) => r.toJson()).toList(),
  };

  factory RepairResult.fromJson(Map<String, dynamic> json) => RepairResult(
    userInfo: RepairUserInfo.fromJson(json['userInfo'] as Map<String, dynamic>),
    records: (json['records'] as List)
        .map((r) => RepairRecord.fromJson(r as Map<String, dynamic>))
        .toList(),
  );
}

class RepairService {
  static String _decodeA(String s) {
    return s
        .split('A')
        .where((p) => p.isNotEmpty)
        .map((p) => String.fromCharCode(int.parse(p)))
        .join();
  }

  static dynamic _decodeResponse(Map<String, dynamic> body) {
    final raw = body['data'];
    if (raw is String && raw.contains('A')) {
      try {
        return jsonDecode(_decodeA(raw));
      } catch (e, stackTrace) {
        talker.debug('报修接口编码响应解析失败', e, stackTrace);
      }
    }
    return body;
  }

  Future<Map<String, dynamic>> _api(
    Dio dio,
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    final resp = await dio.post(
      '$hqglBaseUrl/$path',
      data: data ?? {},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.json,
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    final body = resp.data as Map<String, dynamic>;
    final decoded = _decodeResponse(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return body;
  }

  Future<CasSession> login(String username, String password) async {
    final cas = CasService();
    final hqglLoginUrl = '$hqglBaseUrl/sys/zflogintoken';

    // REST path: HQGL uses CAS OAuth2, so we break the chain into steps
    final st1 = await cas.getServiceTicket(username, password, hqglLoginUrl);
    if (st1 != null) {
      final jar = CookieJar();
      final dio = DioFactory.createNaked(
        cookieJar: jar,
        connectTimeout: requestTimeout,
        receiveTimeout: requestTimeout,
      );
      try {
        // zflogintoken validates ST → redirects to OAuth2 authorize
        var resp = await _noFollow(dio, '$hqglLoginUrl?ticket=$st1');
        final oauthUrl = resp.headers.value('location') ?? '';
        if (oauthUrl.isEmpty) throw AuthException('HQGL OAuth 重定向失败');

        // OAuth2 authorize stores state → redirects to CAS login
        resp = await _noFollow(dio, oauthUrl);
        final casUrl = resp.headers.value('location') ?? '';
        final cbService =
            Uri.tryParse(casUrl)?.queryParameters['service'] ?? '';
        if (cbService.isEmpty) throw AuthException('HQGL OAuth 回调地址获取失败');

        // Get ST for callbackAuthorize and complete the OAuth2 flow
        final st2 = await cas.getServiceTicket(username, password, cbService);
        if (st2 == null) throw AuthException('HQGL OAuth ST 获取失败');

        final sep = cbService.contains('?') ? '&' : '?';
        await followRedirectsManually(dio, '$cbService${sep}ticket=$st2');
        return CasSession(dio, jar);
      } catch (e) {
        dio.close(force: true);
        if (e is AuthException) rethrow;
        // Fall through to HTML login
      }
    }

    // Fallback: HTML CAS login
    final session = await cas.loginCas(username, password);
    await followRedirectsManually(
      session.dio,
      '$hqglBaseUrl/sys/transiturl9002?key=xgcas',
    );
    return session;
  }

  Future<Response<String>> _noFollow(Dio dio, String url) => dio.get<String>(
    url,
    options: Options(
      responseType: ResponseType.plain,
      followRedirects: false,
      validateStatus: (s) => s != null,
    ),
  );

  Future<RepairUserInfo> getUserInfo(CasSession session) async {
    final data = await _api(session.dio, 'repair/getUserPhone');
    final m = (data['map'] as Map<String, dynamic>?) ?? {};
    return RepairUserInfo(
      username: '${m['username'] ?? ''}',
      phone: '${m['phone'] ?? ''}',
    );
  }

  Future<List<RepairArea>> getAreas(CasSession session) async {
    final data = await _api(session.dio, 'repair/getParentArea', {
      'status': '0',
    });
    final list = (data['data'] as List?) ?? [];
    return list.cast<Map<String, dynamic>>().map(RepairArea.fromJson).toList();
  }

  Future<List<RepairArea>> getChildAreas(
    CasSession session,
    String parentId,
  ) async {
    final data = await _api(session.dio, 'repair/getAreaListByParent', {
      'parentid': parentId,
    });
    final list = (data['data'] as List?) ?? [];
    return list.cast<Map<String, dynamic>>().map(RepairArea.fromJson).toList();
  }

  Future<List<RepairItem>> getItems(CasSession session, String areaId) async {
    final data = await _api(session.dio, 'repair/getParentItem', {
      'areaid': areaId,
    });
    final list = (data['data'] as List?) ?? [];
    return list.cast<Map<String, dynamic>>().map(RepairItem.fromJson).toList();
  }

  Future<List<RepairItem>> getChildItems(
    CasSession session,
    String parentId,
  ) async {
    final data = await _api(session.dio, 'repair/getChildItem', {
      'parentid': parentId,
    });
    final list = (data['data'] as List?) ?? [];
    return list.cast<Map<String, dynamic>>().map(RepairItem.fromJson).toList();
  }

  Future<List<RepairRecord>> queryRepairs(CasSession session) async {
    final data = await _api(session.dio, 'repair/getMyFormList', {
      'page': '1',
      'limit': '50',
      'areaid': '',
      'itemid': '',
      'status': '',
      'btime': '',
      'etime': '',
      'content': '',
    });
    final list = (data['data'] as List?) ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .map(RepairRecord.fromJson)
        .toList();
  }

  /// Loads the raw detail payload used by the repair platform's “详细” view.
  /// The endpoint returns a decoded map after the platform's lightweight
  /// response envelope has been unwrapped by [_api].
  Future<Map<String, dynamic>> getRepairDetail(
    CasSession session,
    String formUuid,
  ) => _api(session.dio, 'repair/getRepairFormById', {'fid': formUuid});

  /// Converts the platform's detail envelope into a stable app-facing object.
  /// Unknown fields are retained in [raw] so a newer server response can be
  /// displayed without requiring an app update first.
  Future<RepairDetail> getRepairDetails(
    CasSession session,
    String formUuid,
  ) async {
    final payload = await getRepairDetail(session, formUuid);
    Map<String, dynamic> processPayload = const {};
    try {
      processPayload = await _api(session.dio, 'process/getbuslog', {
        'sysid': formUuid,
      });
    } catch (error, stackTrace) {
      // Older repair records can have no workflow log. Keep the form detail
      // usable and let the UI show the milestones available in that response.
      talker.debug('报修流程日志加载失败', error, stackTrace);
    }
    final list = (payload['data'] as List?) ?? const [];
    final forms = list.whereType<Map<String, dynamic>>();
    final form = forms.isEmpty ? <String, dynamic>{} : forms.first;
    final workflow =
        (processPayload['data'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const <Map<String, dynamic>>[];
    return RepairDetail.fromJson(
      {...form, 'processList': workflow},
      raw: {...payload, 'process': processPayload},
    );
  }

  Future<RepairResult> fetchAll(String username, String password) async {
    final session = await login(username, password);
    try {
      final results = await Future.wait([
        getUserInfo(session),
        queryRepairs(session),
      ]);
      return RepairResult(
        userInfo: results[0] as RepairUserInfo,
        records: results[1] as List<RepairRecord>,
      );
    } finally {
      session.close();
    }
  }

  Future<({String token, String url})> getUploadToken(
    CasSession session,
  ) async {
    final data = await _api(session.dio, 'process/getuploadtoken');
    return (token: '${data['msg'] ?? ''}', url: '${data['url'] ?? ''}');
  }

  Future<String> uploadImage(
    CasSession session, {
    required String uploadUrl,
    required String token,
    required File file,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
    });
    final resp = await session.dio.post(
      '$uploadUrl?token=$token',
      data: formData,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    final body = resp.data as Map<String, dynamic>;
    if (body['code'] != 0) {
      throw AuthException('${body['msg'] ?? '上传失败'}');
    }
    return '${(body['map'] as Map<String, dynamic>?)?['imgurl'] ?? ''}';
  }

  Future<List<String>> uploadImages(
    CasSession session,
    List<File> files,
  ) async {
    if (files.isEmpty) return [];
    final cred = await getUploadToken(session);
    if (cred.url.isEmpty) throw AuthException('获取上传地址失败');
    final paths = <String>[];
    for (final f in files) {
      final jpeg = await _compressToJpeg(f);
      try {
        final path = await uploadImage(
          session,
          uploadUrl: cred.url,
          token: cred.token,
          file: jpeg,
        );
        paths.add(path);
      } finally {
        if (jpeg.path != f.path) jpeg.deleteSync();
      }
    }
    return paths;
  }

  Future<File> _compressToJpeg(File file) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return file;
    final jpeg = img.encodeJpg(decoded, quality: 80);
    final tmp = File(
      '${Directory.systemTemp.path}/'
      '${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await tmp.writeAsBytes(jpeg);
    return tmp;
  }

  Future<String> submitRepair(
    CasSession session, {
    required String areaId,
    required String itemId,
    required String address,
    required String content,
    required String phone,
    required String repairer,
    String remark = '',
    List<String> images = const [],
  }) async {
    final procData = await _api(session.dio, 'process/getProcess', {
      'systemid': hqglSystemId,
    });
    final procs = (procData['data'] as List?) ?? [];
    if (procs.isEmpty) throw AuthException('无法获取流程');
    final processId = '${(procs[0] as Map<String, dynamic>)['uuid'] ?? ''}';

    final btnData = await _api(session.dio, 'process/getOneBtn', {
      'processid': processId,
    });
    final nodes = (btnData['data'] as List?) ?? [];
    if (nodes.isEmpty) throw AuthException('无法获取提交按钮');
    final node = nodes[0] as Map<String, dynamic>;
    final vb = '${node['visiblebutton'] ?? ''}';
    final idxO = vb.indexOf('(');
    final idxC = vb.indexOf(')');
    if (idxO < 0 || idxC < 0) throw AuthException('无法解析按钮');
    final btnValue = vb.substring(0, idxO);
    final btnCode = vb.substring(idxO + 1, idxC);
    final nodeName = '${node['nodename'] ?? ''}';
    final bNodeCode = '${node['nodecode'] ?? ''}';

    final formResp = await _api(session.dio, 'repair/insertForm', {
      'areauuid': areaId,
      'itemuuid': itemId,
      'address': address,
      'content': content,
      'phone': phone,
      'repairer': repairer,
      'remark': remark,
      'maketime': '',
      'images': images.join(','),
    });
    if (formResp['code'] != 0) {
      throw AuthException('${formResp['msg'] ?? '创建报修单失败'}');
    }
    final orderId =
        '${(formResp['map'] as Map<String, dynamic>?)?['orderid'] ?? ''}';
    if (orderId.isEmpty) throw AuthException('未获取到报修单号');

    final detail = await _api(session.dio, 'repair/getRepairFormById', {
      'fid': orderId,
    });
    final formList = (detail['data'] as List?) ?? [];
    if (formList.isEmpty) throw AuthException('获取报修单详情失败');
    final proObj = jsonEncode(formList[0]);

    final subResp = await _api(session.dio, 'process/subprocess', {
      'btnval': btnValue,
      'proobj': proObj,
      'orderid': orderId,
      'bnodecode': bNodeCode,
      'processid': processId,
      'bnodename': nodeName,
      'nodecode': btnCode,
      'images': images.join(','),
    });
    if (subResp['code'] != 0) {
      throw AuthException('${subResp['msg'] ?? '流程提交失败'}');
    }

    var visibMan =
        '${(subResp['map'] as Map<String, dynamic>?)?['visibman'] ?? ''}';
    final subNodeName =
        '${(subResp['map'] as Map<String, dynamic>?)?['nodename'] ?? ''}';
    final isChange =
        '${(subResp['map'] as Map<String, dynamic>?)?['ischange'] ?? ''}';

    if (isChange == '1') {
      final changeResp = await _api(session.dio, 'process/changeprocess', {
        'busid': orderId,
        'proobj': proObj,
      });
      if (changeResp['code'] == 0) {
        final cv =
            '${(changeResp['map'] as Map<String, dynamic>?)?['visibman'] ?? ''}';
        if (cv.isNotEmpty) visibMan = cv;
      }
    }

    await _api(session.dio, 'repair/updateFormVisibman', {
      'fid': orderId,
      'visibman': visibMan,
    });

    final nodeResp = await _api(session.dio, 'repair/updateFormNode', {
      'fid': orderId,
      'nodecode': btnCode,
      'nodename': subNodeName,
    });
    if (nodeResp['code'] != 0) {
      throw AuthException('${nodeResp['msg'] ?? '更新状态失败'}');
    }

    return orderId;
  }
}
