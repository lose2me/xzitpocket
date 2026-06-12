import 'dart:convert';

import 'package:dio/dio.dart';

import '../constants/network_config.dart';
import 'cas_service.dart';

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
        orderId: '${json['orderid'] ?? ''}',
        content: '${json['content'] ?? ''}',
        areaName: '${json['areaname'] ?? ''}',
        itemName: '${json['itemname'] ?? ''}',
        address: '${json['address'] ?? ''}',
        status: '${json['nodename'] ?? '未知'}',
        createTime: '${json['createtime'] ?? ''}',
      );
}

class RepairResult {
  final RepairUserInfo userInfo;
  final List<RepairRecord> records;

  const RepairResult({required this.userInfo, required this.records});
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
      } catch (_) {}
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
    final session = await CasService().loginCas(username, password);
    await followRedirectsManually(
      session.dio,
      '$hqglBaseUrl/sys/transiturl9002?key=xgcas',
    );
    return session;
  }

  Future<RepairUserInfo> getUserInfo(CasSession session) async {
    final data = await _api(session.dio, 'repair/getUserPhone');
    final m = (data['map'] as Map<String, dynamic>?) ?? {};
    return RepairUserInfo(
      username: '${m['username'] ?? ''}',
      phone: '${m['phone'] ?? ''}',
    );
  }

  Future<List<RepairArea>> getAreas(CasSession session) async {
    final data = await _api(session.dio, 'repair/getParentArea', {'status': '0'});
    final list = (data['data'] as List?) ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .map(RepairArea.fromJson)
        .toList();
  }

  Future<List<RepairArea>> getChildAreas(
    CasSession session,
    String parentId,
  ) async {
    final data = await _api(
      session.dio,
      'repair/getAreaListByParent',
      {'parentid': parentId},
    );
    final list = (data['data'] as List?) ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .map(RepairArea.fromJson)
        .toList();
  }

  Future<List<RepairItem>> getItems(
    CasSession session,
    String areaId,
  ) async {
    final data = await _api(
      session.dio,
      'repair/getParentItem',
      {'areaid': areaId},
    );
    final list = (data['data'] as List?) ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .map(RepairItem.fromJson)
        .toList();
  }

  Future<List<RepairItem>> getChildItems(
    CasSession session,
    String parentId,
  ) async {
    final data = await _api(
      session.dio,
      'repair/getChildItem',
      {'parentid': parentId},
    );
    final list = (data['data'] as List?) ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .map(RepairItem.fromJson)
        .toList();
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

  Future<String> submitRepair(
    CasSession session, {
    required String areaId,
    required String itemId,
    required String address,
    required String content,
    required String phone,
    required String repairer,
    String remark = '',
  }) async {
    final procData = await _api(
      session.dio,
      'process/getProcess',
      {'systemid': hqglSystemId},
    );
    final procs = (procData['data'] as List?) ?? [];
    if (procs.isEmpty) throw AuthException('无法获取流程');
    final processId = '${(procs[0] as Map<String, dynamic>)['uuid'] ?? ''}';

    final btnData = await _api(
      session.dio,
      'process/getOneBtn',
      {'processid': processId},
    );
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
      'images': '',
    });
    if (formResp['code'] != 0) {
      throw AuthException('${formResp['msg'] ?? '创建报修单失败'}');
    }
    final orderId =
        '${(formResp['map'] as Map<String, dynamic>?)?['orderid'] ?? ''}';
    if (orderId.isEmpty) throw AuthException('未获取到报修单号');

    final detail = await _api(
      session.dio,
      'repair/getRepairFormById',
      {'fid': orderId},
    );
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
      'images': '',
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
      final changeResp = await _api(
        session.dio,
        'process/changeprocess',
        {'busid': orderId, 'proobj': proObj},
      );
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
