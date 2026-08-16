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
  final String orderId;
  final String content;
  final String areaName;
  final String itemName;
  final String address;
  final String status;
  final String createTime;

  const RepairRecord({
    required this.orderId,
    required this.content,
    required this.areaName,
    required this.itemName,
    required this.address,
    required this.status,
    required this.createTime,
  });

  factory RepairRecord.fromJson(Map<String, dynamic> json) => RepairRecord(
    orderId: '${json['orderid'] ?? json['orderId'] ?? ''}',
    content: '${json['content'] ?? ''}',
    areaName: '${json['areaname'] ?? json['areaName'] ?? ''}',
    itemName: '${json['itemname'] ?? json['itemName'] ?? ''}',
    address: '${json['address'] ?? ''}',
    status: '${json['nodename'] ?? json['status'] ?? '未知'}',
    createTime: '${json['createtime'] ?? json['createTime'] ?? ''}',
  );

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'content': content,
    'areaName': areaName,
    'itemName': itemName,
    'address': address,
    'status': status,
    'createTime': createTime,
  };
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
        ignoreCertificate: true,
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
