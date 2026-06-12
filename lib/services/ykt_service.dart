import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/network_config.dart';
import 'cas_service.dart';

class YktBalanceResult {
  final String balance;
  final String cardNo;

  const YktBalanceResult({required this.balance, required this.cardNo});
}

class YktTransaction {
  final String time;
  final String location;
  final String amount;
  final String balance;
  final String type;

  const YktTransaction({
    required this.time,
    required this.location,
    required this.amount,
    required this.balance,
    required this.type,
  });
}

class YktDetailResult {
  final YktBalanceResult balance;
  final List<YktTransaction> transactions;
  final String? txnError;

  const YktDetailResult({required this.balance, required this.transactions, this.txnError});
}

class YktService {
  Future<CasSession> _login(String username, String password) {
    return CasService().loginCas(
      username,
      password,
      serviceUrl: '$myuBaseUrl/yikat-detail',
    );
  }

  Future<YktDetailResult> getDetail(String username, String password) async {
    final session = await _login(username, password);
    final dio = session.dio;
    final headers = {'Referer': '$myuBaseUrl/yikat-detail'};

    try {
      // Fetch balance
      final r = await dio.get(
        '$myuBaseUrl/api/yikat/info',
        options: Options(
          responseType: ResponseType.json,
          headers: headers,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      if (r.statusCode != 200) throw AuthException('查询余额失败');

      final data = r.data;
      if (data is! Map<String, dynamic>) {
        throw AuthException('查询余额失败: 响应格式错误');
      }
      final items = (data['data'] as List?) ?? [];
      if (items.isEmpty) throw AuthException('未查询到一卡通信息');

      final first = items[0] as Map<String, dynamic>;
      final balance = YktBalanceResult(
        balance: '${first['ye'] ?? ''}',
        cardNo: '${first['kh'] ?? ''}',
      );

      // Fetch recent transactions (last 30 days)
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 30));
      String fmt(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final transactions = <YktTransaction>[];
      String? txnError;
      try {
        final tr = await dio.post(
          '$myuBaseUrl/api/yikat/consumerList',
          data: {
            'currentPage': 1,
            'pageNumber': 50,
            'kssj': fmt(start),
            'jssj': fmt(now),
            'jylx': '',
          },
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            responseType: ResponseType.json,
            headers: headers,
            validateStatus: (s) => s != null && s < 500,
          ),
        );
        debugPrint('YKT txn status: ${tr.statusCode}');
        debugPrint('YKT txn data: ${tr.data}');
        txnError = 'HTTP ${tr.statusCode}: ${tr.data}';
        if (tr.statusCode == 200 && tr.data is Map<String, dynamic>) {
          final trData = tr.data as Map<String, dynamic>;
          final dataMap = trData['data'] as Map<String, dynamic>? ?? {};
          final trItems = (dataMap['items'] as List?) ?? [];
          if (trItems.isNotEmpty) txnError = null;
          for (final item in trItems) {
            if (item is Map<String, dynamic>) {
              transactions.add(YktTransaction(
                time: '${item['jysj'] ?? ''}',
                location: '${item['zd'] ?? ''}',
                amount: '${item['jye'] ?? ''}',
                balance: '${item['ye'] ?? ''}',
                type: '${item['jylxm'] ?? ''}',
              ));
            }
          }
        }
      } catch (e) {
        debugPrint('YKT txn error: $e');
        txnError = '$e';
      }

      return YktDetailResult(balance: balance, transactions: transactions, txnError: txnError);
    } finally {
      session.close();
    }
  }
}
