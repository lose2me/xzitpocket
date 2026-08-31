import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/constants/network_config.dart';
import 'package:xzitpocket/services/cas_service.dart';

void main() {
  test('抓取学业总览 HTML 存文件', () async {
    final session = await CasService().loginJw(
      '25070100246',
      'Lfy@070603',
    );
    try {
      final resp = await session.dio.get(
        '$jwBaseUrl/xsxy/xsxyqk_cxXsxyqkIndex.html?gnmkdm=N105515&layout=default',
        options: Options(responseType: ResponseType.plain),
      );
      final body = resp.data.toString();
      File('/tmp/academic.html').writeAsStringSync(body);
      print('写入 /tmp/academic.html 长度=${body.length}');
      print('yqxf 出现次数: ${"yqxf".allMatches(body).length}');
      print('title1 出现次数: ${"title1".allMatches(body).length}');
      print('sfmjd 出现次数: ${"sfmjd".allMatches(body).length}');
    } finally {
      session.close();
    }
  });
}
