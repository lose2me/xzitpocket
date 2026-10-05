import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/services/repair_service.dart';

void main() {
  test('parses repair detail identity, attachments, and workflow fields', () {
    final detail = RepairDetail.fromJson({
      'uuid': 'FORM-1',
      'orderid': '2609150140',
      'content': '水池堵塞',
      'nodename': '已完工',
      'createtime': '2026-09-15 22:23',
      'jdrq': '2026-09-16 06:53',
      'repairer': '吴**',
      'teamname': '中心综合组',
      'imgs': [
        {
          'lookpath': 'http://example.test/photo.jpg',
          'imgurl': 'upload/photo.jpg',
        },
      ],
      'processList': [
        {
          'nodename': '已提交',
          'operatetime': '2026-09-15 22:23',
          'operatorName': '学生',
        },
        {
          'nodename': '已完工',
          'operatetime': '2026-09-16 06:53',
          'operatorName': '吴**',
          'current': true,
        },
      ],
    });

    expect(detail.formUuid, 'FORM-1');
    expect(detail.orderId, '2609150140');
    expect(detail.attachments.single.url, 'http://example.test/photo.jpg');
    expect(detail.steps, hasLength(2));
    expect(detail.steps.first.name, '已完工');
    expect(detail.steps.first.current, isTrue);
  });
}
